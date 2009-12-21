require 'project_status_helper'

class StatusController < ApplicationController

  skip_before_filter :extract_user, :only => [ :history, :project ]

  def messages
    if request.get?

      @messages = StatusMessage.find :all,
        :conditions => "ISNULL(deleted_at)",
        :limit => params[:limit],
        :order => 'status_messages.created_at DESC',
        :include => :user
      @count = StatusMessage.find( :first, :select => 'COUNT(*) AS cnt' ).cnt

    elsif request.put?

      # check permissions
      unless permissions.status_message_create
        render_error :status => 403, :errorcode => "permission denied",
          :message => "message(s) cannot be created, you have not sufficient permissions"
        return
      end

      new_messages = ActiveXML::Node.new( request.raw_post )

      begin
        if new_messages.has_element? 'message'
          # message(s) are wrapped in outer xml tag 'status_messages'
          new_messages.each_message do |msg|
            message = StatusMessage.new
            message.message = msg.to_s
            message.severity = msg.severity
            message.user = @http_user
            message.save
          end
        else
          # just one message, NOT wrapped in outer xml tag 'status_messages'
          message = StatusMessage.new
          message.message = new_messages.to_s
          message.severity = new_messages.severity
          message.user = @http_user
          message.save
        end
        render_ok
      rescue
        render_error :status => 400, :errorcode => "error creating message(s)",
          :message => "message(s) cannot be created"
        return
      end

    elsif request.delete?

      # check permissions
      unless permissions.status_message_create
        render_error :status => 403, :errorcode => "permission denied",
          :message => "message cannot be deleted, you have not sufficient permissions"
        return
      end

      begin
        StatusMessage.find( params[:id] ).delete
        render_ok
      rescue
        render_error :status => 400, :errorcode => "error deleting message",
          :message => "error deleting message - id not found or not given"
      end

    else

      render_error :status => 400, :errorcode => "only_put_or_get_method_allowed",
        :message => "only PUT or GET method allowed for this action"
      return

    end
  end

  def workerstatus
     send_data ( Rails.cache.read 'workerstatus')
  end

  def history
     hours = params[:hours] || "24"
     starttime = Time.now.to_i - hours.to_i * 3600
     @data = Hash.new
     lines = StatusHistory.find(:all, :conditions => [ "time >= ? AND `key` = ?", starttime, params[:key] ])
     lines.each do |l|
	@data[l.time] = l.value
     end
  end

  def update_workerstatus_cache
      ret = backend.direct_http( URI('/build/_workerstatus') )
      mytime = Time.now.to_i
      Rails.cache.write('workerstatus', ret)
      data = REXML::Document.new(ret)
      data.root.each_element('blocked') do |e|
        line = StatusHistory.new
        line.time = mytime
        line.key = 'blocked_%s' % [ e.attributes['arch'] ]
        line.value = e.attributes['jobs']
        line.save
      end
      data.root.each_element('waiting') do |e|
        line = StatusHistory.new
        line.time = mytime
        line.key = 'waiting_%s' % [ e.attributes['arch'] ]
        line.value = e.attributes['jobs']
        line.save
      end

      allworkers = Hash.new
      workers = Hash.new
      %w{building idle}.each do |state|
        data.root.each_element(state) do |e|
          id=e.attributes['workerid']
          if workers.has_key? id
             logger.debug 'building+idle worker'
             next
          end
          workers[id] = 1
          key = state + '_' + e.attributes['hostarch']
          begin
            allworkers[key] = allworkers[key] + 1
          rescue
            allworkers[key] = 1
          end
        end
      end

      allworkers.each do |key,value|
        line = StatusHistory.new
        line.time = mytime
        line.key = key
        line.value = value
        line.save
      end

  end

  def project
     dbproj = DbProject.find_by_name(params[:id])
     if ! dbproj
        render_error :status => 404, :errorcode => "no such project",
          :message => "project %s does not exist" % params[:id]
        return
     end
     key='project_status_xml_%s' % dbproj.name
     xml = Rails.cache.fetch(key, :expires_in => 10.minutes) do
       @packages = dbproj.complex_status(backend)
       render_to_string 
     end
     render :text => xml
  end
end

