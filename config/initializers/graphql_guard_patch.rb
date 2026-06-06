# graphql-guard 2.0.0 calls `.graphql_definition.metadata[:mask]` on all schema
# members during query validation. GraphQL::Schema::TypeMembership (which
# represents "type X implements interface Y") doesn't define `graphql_definition`
# in graphql-ruby 1.13, causing a NoMethodError during eager loading in
# production. TypeMembership objects don't carry authorization masks, so we
# provide a stub that returns an empty metadata hash to let the guard skip them.
module GraphQLTypeMembershipPatch
  class NullDefinition
    def metadata
      {}
    end
  end

  def graphql_definition
    @_null_definition ||= NullDefinition.new
  end
end

GraphQL::Schema::TypeMembership.prepend(GraphQLTypeMembershipPatch)
