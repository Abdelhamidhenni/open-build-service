class Group < ActiveXML::Base

  def self.list(prefix=nil)
    group_list = Rails.cache.fetch("group_list_#{prefix.to_s}", :expires_in => 10.minutes) do
      transport ||= ActiveXML::Config::transport_for(:person)
      path = "/group?prefix=#{prefix}"
      begin
        logger.debug "Fetching group list from API"
        response = transport.direct_http URI("https://#{path}"), :method => "GET"
        names = []
        Collection.new(response).each {|group| names << group.name}
        names
      rescue ActiveXML::Transport::Error => e
        message, _, _ = ActiveXML::Transport.extract_error_message e
        raise ListError, message
      end
    end
    return group_list
  end

end
