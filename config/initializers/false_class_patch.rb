# Formtastic 2.x uses `!name =~ /regex/` which, due to operator precedence, evaluates
# as `(!name) =~ /regex/`. If `name` is truthy, `!name` is false; if nil/false, `!name`
# is true. Ruby 3 removed `=~` from both FalseClass and TrueClass — restore as no-op.
class FalseClass
  def =~(_other)
    nil
  end
end

class TrueClass
  def =~(_other)
    nil
  end
end
