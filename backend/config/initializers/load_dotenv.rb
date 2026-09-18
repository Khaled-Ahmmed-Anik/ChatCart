if Rails.env.development? && ENV["DOTENV_LOADED_IN_DEVELOPMENT"].blank?
  require "dotenv"

  Dotenv.load(Rails.root.join(".env"))
end
