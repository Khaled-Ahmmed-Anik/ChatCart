class ChatcartSchema < GraphQL::Schema
  query Types::QueryType
  mutation Types::MutationType

  use GraphQL::Dataloader
  max_depth 15
  max_complexity 200

  rescue_from(ActiveRecord::RecordNotFound) do
    raise GraphQL::ExecutionError, "Record not found"
  end
end
