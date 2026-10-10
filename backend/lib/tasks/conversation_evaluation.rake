namespace :conversation do
  desc "Evaluate the local multilingual intent classifier against the reviewed benchmark"
  task evaluate: :environment do
    report = ConversationEvaluationRunner.new.call
    puts JSON.pretty_generate(report)
    abort "Conversation evaluation thresholds failed" unless report[:passing]
  end
end
