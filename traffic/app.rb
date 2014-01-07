#!/usr/bin/env ruby
# encoding: utf-8

class AppController < Sinatra::Base
  enable :sessions

  configure {
    set :server, :puma
  }

  RRD_FOLDER=ENV['RRD_FOLDER'] ? ENV['RRD_FOLDER'] : nil

  WHITELIST_GRID = ["__SUMMARY__"]
  WHITELIST_HOST = ["__SUMMARY__"]

  helpers do
    def store()
      if RRD_FOLDER and File.directory? RRD_FOLDER
        base_folder = RRD_FOLDER
        grids = WHITELIST_GRID & Dir.entries(base_folder).delete_if {|e| ['.', '..'].include? e }

        rst = {}
        grids.each do |grid|
          grid_folder = "#{base_folder}/#{grid}"
          next unless File.directory? grid_folder

          rst[grid] = {}
          hosts = WHITELIST_HOST & Dir.entries(grid_folder).delete_if {|e| ['.', '..'].include? e }
          hosts.each do |host|
            host_folder = "#{grid_folder}/#{host}"
            next unless File.directory? host_folder

            rst[grid][host] = {}
            channels = Dir.entries(host_folder).delete_if {|e| ['.', '..'].include? e }
            rst[grid][host] = channels
          end
        end
        return rst
      else
        return {}
      end
    end

    def nl2br(s)
      s.to_s.gsub(/\r\n|\r|\n/, "<br />\n")
    end
    alias :h :nl2br

    def get_color(idx=0)
      colors = ["#0033FF", "#FF3300", "#00CC00", "#FFAA00", "#CC00FF", "#808000", "#660066", "#BB148C", "#808080", "#20B2AA", "#D02090", "40E0D0", "FF6347", "468247"]

      return colors[ idx % colors.length ]
    end
  end

  ['/', '/traffic'].each do |loc|
    get loc do
      @store = store()
      @period = params[:period] ? params[:period] : '1D'

      haml :traffic
    end
  end

  get '/traffic/graph/:grid/:host/:channel/:metric' do
    @grid = params[:grid]
    @host = params[:host]
    @channel = params[:channel]
    @metric = params[:metric] || "default"

    @period = params[:period] ? params[:period] : 3600
    @width = params[:width] ? params[:width] : 280
    @height = params[:height] ? params[:height] : 200

    channel_folder = "#{RRD_FOLDER}/#{@grid}/#{@host}/#{@channel}"

    if @metric.nil? or @metric == "default"
      rrdfile_reqs = "#{channel_folder}/requests.rrd";
      rrdfile_byts = "#{channel_folder}/bytes_out.rrd";

      last_reqs_cmd = `rrdtool lastupdate #{rrdfile_reqs}`;
      last_reqs = last_reqs_cmd.strip.split(" ")[-1]
      last_byts_cmd = `rrdtool lastupdate #{rrdfile_byts}`;
      last_byts = last_byts_cmd.strip.split(" ")[-1]

      request_size = 100000;
      request_size = last_reqs.to_i == 0 ? 1000000 : (last_byts.to_f*8)/last_reqs.to_i;
      scale = 1 / request_size;

      graph = TrendGraph.new
      graph.use_default_settings(true)

      graph.set('vertical-label',  "bits/s");
      graph.set('title', "#{@channel}-#{@metric} [ last #{@period} ]");

      graph.set('right-axis-label', 'requests/s')
      graph.set('right-axis', "#{scale}:0")
      graph.opt('-alt-y-grid')
      graph.opt('-rigid')

      graph.set('start', "-#{@period}");
      graph.set('end', "N");
      graph.set('width', @width);
      graph.set('height', @height);

      graph.def("requests", "#{rrdfile_reqs}:value:AVERAGE")
      graph.def("bytes_out", "#{rrdfile_byts}:value:AVERAGE")
      graph.cdef("reqs", "requests,#{request_size},*")
      graph.cdef("bits_out", "bytes_out,8,*")
      graph.area("bits_out", "traffic_out", "#00FF33")
      graph.gprint("bits_out")
      graph.line("reqs", "requests", "#0022e9")
      graph.gprint("requests")

      cmd = graph.cmd

    elsif @metric == "errors"
      errors = [200, 400, 403, 404, 408, 500, 502, 504]

      graph = TrendGraph.new
      graph.use_default_settings(true)

      graph.set('start', "-#{@period}");
      graph.set('end', "N");
      graph.set('width', @width);
      graph.set('height', @height);
      graph.set('vertical-label',  "RPS");
      graph.set('title', "#{@channel}-#{@metric} [ last #{@period} ]");

      idx = 0
      errors.each do |error_code|
          rrdfile = "#{channel_folder}/#{error_code}.rrd"
          if File.exists? rrdfile
              graph.def("code_#{error_code}_count", "#{rrdfile}:value:AVERAGE")
              graph.cdef("code_#{error_code}", "code_#{error_code}_count")
              graph.line("code_#{error_code}", "code_#{error_code}", get_color(idx))
              graph.gprint("code_#{error_code}")
              idx += 1
          end
          rrdfile = nil;
      end

      cmd = graph.cmd

    end

    if params[:debug]
      content_type 'text/plain'
      cmd
    else
      content_type 'image/gif'

      `#{cmd}`
    end
  end
end
