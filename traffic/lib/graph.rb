#/usr/bin/env ruby

class TrendGraph
  attr_reader :cmd

  def initialize(init_cmd = nil)
    @cmd = "rrdtool graph - "
    @cmd += init_cmd if init_cmd
  end

  def set(arg, value)
    @cmd += "--#{arg} '#{value}' "
  end

  def opt(opt)
    @cmd += "-#{opt} "
  end

  def use_default_settings(use=true)
    if use
      set('color', 'BACK#E0E0E0')
      set('color', 'SHADEA#FFFFFF')
      set('color', 'SHADEB#FFFFFF')
      opt('M')
    end
  end

  def def(def_name, source)
    @cmd += "DEF:#{def_name}=#{source} "
  end

  def cdef(cdef_name, def_name)
    @cmd += "CDEF:#{cdef_name}=#{def_name} "
  end

  def area(cdef_name, title, color = "#00FF33")
    @cmd += "AREA:#{cdef_name}#{color}:'#{title || cdef_name}' "
  end

  def line(cdef_name, title, color = "#0022e9")
    @cmd += "LINE:#{cdef_name}#{color}:'#{title || cdef_name}' "
  end

  def gprint(cdef_name)
    @cmd += "GPRINT:#{cdef_name}:MAX:'%8.1lf' "
    @cmd += "GPRINT:#{cdef_name}:AVERAGE:'%8.1lf' "
    @cmd += "GPRINT:#{cdef_name}:LAST:'%8.1lf\\n' "
  end

  def print_cmd()
    puts @cmd
  end

  def draw()
    `#{@cmd}`
  end

end
