# This is a list of common search terms and the action that they should relate to.
# Each target action is one in the Service vocabulary distinct words list

require "yaml"

module DIY
  phrases = YAML.load("../data/phrases.yml")
end