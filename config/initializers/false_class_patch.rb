# Formtastic 2.x calls `=~` on column type values which can be `false` in Ruby 3.x.
# Ruby 3 removed `=~` from FalseClass — restore it as a no-op to match Ruby 2 behaviour.
class FalseClass
  def =~(_other)
    nil
  end
end
