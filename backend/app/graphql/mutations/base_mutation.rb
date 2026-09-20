module Mutations
  class BaseMutation < GraphQL::Schema::Mutation
    object_class Types::BaseObject
    field_class Types::BaseField

    private

    def require_management_role!
      return if context[:current_user].role.in?(%w[owner admin])

      raise GraphQL::ExecutionError, "Forbidden"
    end
  end
end
