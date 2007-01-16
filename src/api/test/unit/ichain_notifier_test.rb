require File.dirname(__FILE__) + '/../test_helper'
require 'ichain_notifier'

class IchainNotifierTest < Test::Unit::TestCase
  FIXTURES_PATH = File.dirname(__FILE__) + '/../fixtures'
  CHARSET = "utf-8"

  fixtures :users

  include ActionMailer::Quoting

  def setup
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
    
    @user = User.find_by_login "tom"
    assert_valid @user

    @expected = TMail::Mail.new
    @expected.set_content_type "text", "plain", { "charset" => CHARSET }
    @expected.from    = 'admin@opensuse.org'
    @expected.to      = @user.email
  end

  def test_reject
    @expected.subject = 'Buildservice account request rejected'
    @expected.body    = read_fixture('reject')
    @expected.date    = Time.now

    assert_equal @expected.encoded, IchainNotifier.create_reject(@user).encoded
  end

  def test_approval
    @expected.subject = 'Your openSUSE buildservice account is active'
    @expected.body    = read_fixture('approval')
    @expected.date    = Time.now

    assert_equal @expected.encoded, IchainNotifier.create_approval(@user).encoded
  end

  private
    def read_fixture(action)
      IO.readlines("#{FIXTURES_PATH}/ichain_notifier/#{action}")
    end

    def encode(subject)
      quoted_printable(subject, CHARSET)
    end
end
