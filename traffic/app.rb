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

  end

  ['/', '/traffic'].each do |loc|
    get loc do
      @store = store()
      @period = params[:period] ? params[:period] : '1D'

      haml :traffic
    end
  end

  get '/traffic/graph/:grid/:host/:channel' do
    @grid = params[:grid]
    @host = params[:host]
    @channel = params[:channel]

    @period = params[:period] ? params[:period] : 3600
    @width = params[:width] ? params[:width] : 280
    @height = params[:height] ? params[:height] : 200

    channel_folder = "#{RRD_FOLDER}/#{@grid}/#{@host}/#{@channel}"

    rrdfile_reqs = "#{channel_folder}/requests.rrd";
    rrdfile_byts = "#{channel_folder}/bytes_out.rrd";

    last_reqs_cmd = `rrdtool lastupdate #{rrdfile_reqs}`;
    last_reqs = last_reqs_cmd.strip.split(" ")[-1]
    last_byts_cmd = `rrdtool lastupdate #{rrdfile_byts}`;
    last_byts = last_byts_cmd.strip.split(" ")[-1]

    request_size = 100000;
    request_size = last_reqs.to_i == 0 ? 1000000 : (last_byts.to_f*8)/last_reqs.to_i;
    scale = 1 / request_size;

    cmd = "rrdtool graph - \
      --right-axis-label 'requests/s' --right-axis #{scale}:0 --alt-y-grid --rigid \
      --color 'BACK#E0E0E0' --color 'SHADEA#FFFFFF' --color 'SHADEB#FFFFFF' \
      --start '-#{@period}' --end N --width #{@width} --height #{@height} \
      --title '#{@channel}  [ last #{@period} ]' --vertical-label 'bits/s' \
      DEF:requests=#{rrdfile_reqs}:value:AVERAGE \
      DEF:bytes_out=#{rrdfile_byts}:value:AVERAGE \
      CDEF:reqs=requests,#{request_size},* \
      CDEF:bits_out=bytes_out,8,* \
      AREA:bits_out#00FF33:traffic_out \
      GPRINT:bits_out:MAX:' Max\\:%8.2lf %s' \
      GPRINT:bits_out:AVERAGE:' Average\\:%8.2lf %s' \
      GPRINT:bits_out:LAST:' Current\\:%8.2lf %s\\n' \
      LINE:reqs#0022e9:'requests   ' \
      GPRINT:requests:MAX:' Max\\:%8.2lf %s' \
      GPRINT:requests:AVERAGE:' Average\\:%8.2lf %s' \
      GPRINT:requests:LAST:' Current\\:%8.2lf %s\\n' \
    ";

    if params[:debug]
      content_type 'text/plain'
      cmd
    else
      content_type 'image/gif'

      `#{cmd}`
    end
  end
end
