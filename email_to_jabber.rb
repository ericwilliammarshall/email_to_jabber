require 'rubygems'
require 'xmpp4r'
include Jabber
 
class Agent
 
  def initialize
    user = JID.new("user@somewhere.com/here")
    @password = "somepasswd"
    @client = Client.new(user)
  end
 
  def connect(server_name, port)
    #Connect to server sending username and password
    @client.connect(server_name, port)
    @client.auth(@password)
 
    post_connect if @client
  end
 
  def post_connect
    #Set default presence to available
    status = Presence.new.set_type(:available)
    @client.send(status)
    #Start a new queue array
    @queue = []
    register_callbacks
  end
 
  def disconnect
    @client.close
  end
 
  def register_callbacks
    @client.add_message_callback do |message|
      @queue << message unless message.body.nil?
    end
  end
 
  def send_message(recipient, text, reply=false)
    message = Message.new(recipient)
    message.type = :chat
      if reply
        message.body = "Thank you for sending me the message: " << text
      else
        message.body = text
      end
      @client.send(message)
  end
 
  def start_worker_thread
    worker_thread = Thread.new do
      puts "worker thread started..."
      #Start a loop to listen for incoming messages
      loop do
        if !@queue.empty?
          @queue.each do |item|
            puts item
            #Remove the resource from the user
            sender = item.from.to_s.sub(/\/.+$/, '')
 
            #If the message included the line command: create a new command object and attempt to run it
            if item.body.include? "command: "
              send_message(sender, "I'll try to run " << item.body.to_s, false)
              input_command = Command.new
              command_result = input_command.run_command(item.body.to_s)
              send_message(sender, command_result, false)
            else
              send_message(sender, item.body.to_s, true)
            end
            @queue.shift
            puts "Queue is now empty" if @queue.empty?
          end
        end
      end
      sleep 1
    end
    worker_thread.join
  end
end
 
class Command
  @@allowable_commands = %w{ ipconfig ifconfig iisreset ping dig }
 
  def run_command(command)
    #Strip the command part out of the string - we don't need it any more.
    command.slice!("command: ")
 
    #Create an array for the arguments
    arguments = command.split(" ")
    arguments.delete_at(0) # Delete the first index, this is the command itself without arguments
    arguments.each {|x| puts "Argument: #{x}"}
 
    #Loop through the arguments and delete them from the command string
    arguments.each {|x| command.slice!(x)}
 
    puts "This is the command after munging #{command.strip!}"
 
    if @@allowable_commands.include? command
      puts "#{command} is an allowed command"
      result = `#{command} #{arguments.join(" ")}`
    else
      result = "#{command} cannot be run"
    end
    puts result
    return result
  end
end
 
bot = Agent.new
bot.connect("chat.my.channel", "5222")
bot.send_message("me@someemail.com", "Bot reporting for duty at #{Time.now}", false)
bot.start_worker_thread
