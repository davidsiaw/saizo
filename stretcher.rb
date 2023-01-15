require 'set'

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

  class ItemDSL
    def initialize(itemname)
      @itemname = itemname
      @info = {}
    end

    def method_missing(name, *args)
      @info[name] = args[0]
    end

    def item
      Item.new(@itemname, @info)
    end
  end

  class Item
    attr_reader :name

    # hardened item
    def initialize(name, info)
      @name = name
      @info = info
    end

    def method_missing(name)
      if @info.key? name
        return @info[name]
      end

      super
    end

    def respond_to?(name)
      return true if @info.key? name

      false
    end

    def properties
      @info.keys
    end

    def to_s
      "<Item #{@name} #{@info.to_s}>"
    end
  end

  class Pouch
    def initialize(clumpname, itemlist)
      @clumpname = clumpname
      @itemlist = itemlist
    end

    def apply(dsl)
      properties = {}
      @itemlist.each_with_index do |item, index|
        if item.is_a? Item
          item_name = :"#{@clumpname}_#{item.name}"
          dsl.var dsl.send(item_name), Int >= 0

          item.properties.each do |prop|
            properties[prop] ||= []
            properties[prop] << {
              propname: item_name,
              item: item
            }
          end

        elsif item.is_a? Slot
          slot = item

          full = 0

          slot.itemlist.each do |item|
            slot_item_name = :"#{@clumpname}_slot#{index}_#{slot.name}_#{item.name}"

            dsl.var dsl.send(slot_item_name), Int >= 0
            dsl.constraint dsl.send(slot_item_name) <= 1

            full = dsl.send(slot_item_name) + full

            item.properties.each do |prop|
              properties[prop] ||= []
              properties[prop] << {
                propname: slot_item_name,
                item: item
              }
            end
          end

          dsl.constraint full <= 1
        end
      end

      properties.each do |propname, iteminfolist|
        define_singleton_method :"#{propname}_sum" do
          sum = Sym.new(iteminfolist[0][:propname]) * iteminfolist[0][:item].send(:"#{propname}")
          z = iteminfolist[1..-1].each do |iteminfo|
            sum = sum + Sym.new(iteminfo[:propname]) * iteminfo[:item].send(:"#{propname}")
          end
          sum
        end
      end


    end
  end

  class Slot
    attr_reader :itemlist, :name

    def initialize(name, itemlist)
      @name = name.to_s
      @itemlist = itemlist
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

      @items = {}
      @slots = {}
      @clumps = {}
      @engine = 'HiGHS'
    end

    def setengine(engine)
      @engine = engine
    end

    def item(namesym, &block)
      namestring = namesym.to_s

      raise "#{namestring} already exists" if @items.key?(namestring)

      itemdsl = ItemDSL.new(namestring)
      itemdsl.instance_eval(&block)
      # $stderr.puts itemdsl.item
      @items[namestring] = itemdsl.item
    end

    def choice(slotname, *items)
      # create a slot for choice of items
      slot = Slot.new(slotname.to_s, items)
      @slots[slotname.to_s.to_sym] = slot
    end

    def pouch(clumpname, *items)
      clump = Pouch.new(clumpname.to_s, items)
      clump.apply(self)
      @clumps[clumpname.to_s.to_sym] = clump
    end
  
    def method_missing(name, *args)
      return @clumps[name] if @clumps.key? name
      return @items[name] if @items.key? name
      return @slots[name] if @slots.key? name

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
      if @engine != 'Cbc'
        $stderr.puts "time_limit_secs Works only on Cbc. Using #{@engine} so ignoring"
        return
      end
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
          %{println("#var##{k.name}=", convert(BigInt, round(value(#{k.name}))))}
        else
          %{println("#var##{k.name}=", value(#{k.name}))}
        end
      end.join("\n")
    end
  
    def genshowconstraints
      @constraints.each_with_index.map do |c, i|
        %{println("#constraint#con#{i}=", value(#{c.lhs.to_s}))}
      end.join("\n")
    end

    def genshows
      @shows.map do |k,v|
        if v[:type] == :int
          %{println("#show##{k}=", convert(BigInt, round(value(#{v[:expr].to_s}))))}
        else
          %{println("#show##{k}=", value(#{v[:expr].to_s}))}
        end
      end.join("\n")
    end
  
    def genoutput
      <<~OUTPUT
        #{genpvar}
        #{genshowconstraints}
        #{genshows}
  
        println("#top#result=", objective_value(m))
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
        using #{@engine}
  
        m = Model(#{@engine}.Optimizer)
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
  