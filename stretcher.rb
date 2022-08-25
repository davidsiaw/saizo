module ComparableType
    %i[>= <= == < > * / + -].each do |op|
      define_method op do |rhs|
        Expr.new(self, rhs, op)
      end
    end
  end
  
  class Coefflist
    attr_reader :coeffs, :constant
    def initialize(expr)
      @expr = expr
      @coeffs = {}
      @constant = 0
      process!
    end
  
    def process!
      if @expr.is_a? Integer
        @constant = @expr
        return
      end
  
      if @expr.is_a? Sym
        @coeffs[@expr.name] = 1
        return
      end
  
      if @expr.is_a? Expr
        lhs = Coefflist.new(@expr.lhs)
        rhs = Coefflist.new(@expr.rhs)
        if @expr.oper == :*
          lhs.mul(rhs)
        elsif @expr.oper == :+
          lhs.add(rhs)
        else
          p @expr.oper
        end
        @coeffs = lhs.coeffs
        @constant = lhs.constant
      end
    end
  
    def add(rhs)
      @constant += rhs.constant
  
      rhs.coeffs.each do |k, v|
        @coeffs[k] ||= 0
        @coeffs[k] += v
      end
    end
  
    def mul(rhs)
      if rhs.coeffs.count > 0
        raise 'cannot non linear'
      end
  
      @coeffs.each do |k, v|
        @coeffs[k] *= rhs.constant
      end
    end
  
    def to_s
      if coeffs.count.zero?
        return constant.to_s
      end
  
      if coeffs.count == 1 && coeffs.values.first == 1
        return coeffs.keys.first
      end
  
      coeffs.map {|k,v| "#{v} #{k}"}.join(" + ") + " + #{constant} one"
    end
  end
  
  class Expr
    include ComparableType
  
    attr_reader :lhs, :rhs, :oper
  
    def initialize(lhs, rhs, oper)
      @lhs = lhs
      @rhs = rhs
      @oper = oper
    end
  
    def to_s
      "(#{lhs.to_s}) #{oper} (#{rhs.to_s})"
    end
  
    def to_glpk
      if oper == :<= || oper == :>=
        clhs = Coefflist.new(lhs)
        crhs = Coefflist.new(rhs)
        "#{clhs.to_s} #{oper} #{crhs.to_s}"
      else
        Coefflist.new(self).to_s
      end
    end
  end
  
  class Num
    include ComparableType
  
    def initialize(val)
      @val = val
    end
  
    def to_s
      @val.to_s
    end
  end
  
  class Sym
    include ComparableType
  
    attr_reader :name
  
    def initialize(name)
      @name = name
    end
  
    def >=(rhs)
      Expr.new(self, rhs, '>=')
    end
  
    def to_s
      name
    end
  end
  
  class DSL
    def initialize
      @variables = {}
      @constraints = []
      @objective = nil
      @action = nil
      @shows = {}
      @options = {}
    end
  
    def method_missing(name, *args)
      Sym.new(name)
    end
  
    def var(name, expr)
      @variables[name] = expr
    end
  
    def constraint(expr)
      @constraints << expr
    end
  
    def maximize(expr)
      @action = 'Max'
      @objective = expr
    end
  
    def minimize(expr)
      @action = 'Min'
      @objective = expr
    end
  
    def time_limit_secs(secs)
      @options['seconds'] = secs
    end
  
    def show(name, expr)
      @shows[name] = {expr: expr, type: :float}
    end
  
    def show_int(name, expr)
      @shows[name] = {expr: expr, type: :int}
    end
  
    def genvars
      @variables.map do |k,v|
        "@variable(m, #{k.name} #{v.oper} #{v.rhs}, #{v.lhs.name})"
      end.join("\n")
    end
  
    def gencons
      @constraints.each_with_index.map do |c, i|
        "@constraint(m, con#{i}, #{c.to_s})"
      end.join("\n")
    end
  
    def genobj
      return '' unless @objective
  
      "@objective(m, #{@action}, #{@objective.to_s})"
    end
  
    def genpvar
      @variables.map do |k,v|
        if v.lhs.name.to_s == 'Int'
          %{println("#{k.name} = ", convert(BigInt, round(value(#{k.name}))))}
        else
          %{println("#{k.name} = ", value(#{k.name}))}
        end
      end.join("\n")
    end
  
    def genshows
      @shows.map do |k,v|
        if v[:type] == :int
          %{println("#{k} = ", convert(BigInt, round(value(#{v[:expr].to_s}))))}
        else
          %{println("#{k} = ", value(#{v[:expr].to_s}))}
        end
      end.join("\n")
    end
  
    def genoutput
      <<~OUTPUT
        #{genpvar}
        #{genshows}
  
        println("Result: ", objective_value(m))
      OUTPUT
    end
  
    def genoptions
      @options.map do |k,v|
        %{set_optimizer_attribute(m, #{k.inspect}, #{v.inspect})}
      end.join("\n")
    end
  
    def genglpk
      variables = @variables.map do |k,v|
        k.name
      end.join("\n")
  
      bounds = @variables.map do |k,v|
        "#{k.name} #{v.oper} #{v.rhs}"
      end.join("\n")
  
      cons = @constraints.each_with_index.map do |c, i|
        "con#{i}: #{c.to_glpk}"
      end.join("\n")
  
      action = "Minimize"
      action = "Maximize" if @action == "Max"
  
      <<~GLPK
        #{action}
        obj: #{@objective.to_glpk}
  
        Subject To
        #{cons}
  
        Bounds
        #{bounds}
        1 <= one <= 1
  
        Generals
        #{variables}
  
        End
      GLPK
    end
  
    def gen
      <<~CONTENT
        using JuMP
        using Cbc
  
        m = Model(Cbc.Optimizer)
        #{genoptions}
  
        #{genvars}
  
        #{gencons}
  
        #{genobj}
  
        optimize!(m)
  
        #{genoutput}
      CONTENT
    end
  
    def puts(*args)
      $stderr.puts(*args)
    end
  end
  
  class Bin
    extend ComparableType
  end
  
  class Int
    extend ComparableType
  end
  
  class Bool
    extend ComparableType
  end
  
  dsl = DSL.new
  
  dsl.instance_eval(File.read(ARGV[0]), ARGV[0])
  
  puts dsl.gen
  