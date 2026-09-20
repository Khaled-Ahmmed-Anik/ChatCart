namespace :graphql do
  namespace :schema do
    desc "Dump the GraphQL schema used by frontend code generation"
    task dump: :environment do
      path = Rails.root.join("schema.graphql")
      path.write(ChatcartSchema.to_definition)
      puts "Wrote #{path}"
    end
  end
end
