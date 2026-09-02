# auto_register: false
# frozen_string_literal: true

require "hanami/mailer"

module HanamiApp
  class Mailer < Hanami::Mailer
    # Add common mailer behavior here, such as a default sender:
    #
    # from "noreply@example.com"
    #
    # See https://hanakai.org/learn/hanami/mailers for details.
  end
end
