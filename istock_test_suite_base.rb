require "rubygems"
require "./framework/istock_test_suite_config_browser"
require "./framework/istock_test_suite_config_api"
require "./framework/test_suite_base/istock_test_suite_reports"
require "./framework/test_suite_base/istock_test_suite_error_handling"
require "./framework/data/framework_test_case_priorities"
require "sys/uname"

$command_line_args = Array.new(ARGV)

#Just changing some stuff for playing with git

class Net::HTTP
  alias_method :old_initialize, :initialize
  def initialize(*args)
    old_initialize(*args)
    @ssl_context = OpenSSL::SSL::SSLContext.new
    @ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
end

class IstockTestSuiteBase < Test::Unit::TestCase

  attr_reader :istock_browser

  include Istock_Browser_Layer
  include Istock_Framework_Priorities
  include Istock_Test_Suite_Config_Base
  include Istock_Test_Suite_Config_API
  include Istock_Test_Suite_Reports
  include Istock_Test_Suite_Error_Handling
  include Sys

  def run(result)
    Timeout::timeout(@@config.max_time_per_test * 1.10,TestTimeOutError.new)do
      super(result)
    end
  end

  def teardown
    if @_result.faults.size > @@current_fault then
      save_error_report
    end
    teardown_initializer()
    puts "Finished, #{self.name}"
    save_time_report()
    save_memory_report()
  rescue Exception => e
    if @@browser_active then
      @@browser.goto("about:blank")
      @@browser.close
      sleep(5)
    end
    @@error_handling = Istock_Test_Suite_Error_Handling::Error_Handling.new()
    exception = Istock_Test_Suite_Error_Handling::TeardownError.new(e.message,e.backtrace,e.inspect)
    error = @@error_handling.check_error(:exception=>exception,:test_name => self.inspect)
    y error["error_message"]
    error_node = Hash["error_type"=>"","error_message"=>""]
    error_node["error_type"] = "Teardown Failure"
    error_node["error_message"] = error["error_message"] + {"Grid Node Info:" => "IP #{@@config.server_ip} Port#{@@config.server_port}"}
    @@reports.summary.push(error_node)
    @@reports.output_error_report_summary()

    exit!(error["error_code"])
  end

  def setup
    #Grab the test start time
    @time_start = Time.now
    puts @time_start
    puts "Starting, #{self.name}"
    setup_initializer()
    puts self.method_name
    omit_if(!@@test_priorities.shouldTestBeRan(self.method_name, @@config.suite_priority))
    return
  rescue Test::Unit::OmittedError
    raise
  rescue Exception => e
    @@error_handling = Istock_Test_Suite_Error_Handling::Error_Handling.new()
    exception = Istock_Test_Suite_Error_Handling::SetupError.new(e.message,e.backtrace,e.inspect)
    error = @@error_handling.check_error(:exception=>exception,:test_name => self.inspect)
    y error["error_message"]
    error_node = Hash["error_type"=>"","error_message"=>""]
    error_node["error_type"] = "Setup Failure"
    error_node["error_message"] = error["error_message"] + {"Grid Node Info:" => "IP #{@@config.server_ip} Port#{@@config.server_port}"}
    @@reports.summary.push(error_node)
    @@reports.output_error_report_summary()
    if @@browser_active then
      @@browser.goto("about:blank")
      @@browser.close
      sleep(5)
    end
    exit!(error["error_code"])
  end

  def self.startup
    @@current_fault = 0
    @@suite = nil
    @@browser_on = nil
    @@logging = nil
    @@browser_active = false
    self.set_framework()
    self.load_config()
    self.initialize_reporting()
    self.load_framework()
    self.set_logging_level()
    self.startup_initializer()
    if @@browser_on == true then @@site_functions.set_typing_speed(:zippy) end
    return
  rescue Exception => e
    @@error_handling = Istock_Test_Suite_Error_Handling::Error_Handling.new()
    exception = Istock_Test_Suite_Error_Handling::StartupError.new(e.message,e.backtrace,e.inspect)
    error = @@error_handling.check_error(:exception=>exception,:test_name => self.inspect)
    y error["error_message"]
    error_node = Hash["error_type"=>"","error_message"=>""]
    error_node["error_type"] = "Startup Failure"
    error_node["error_message"] = error["error_message"] + {"Grid Node Info:" => "IP #{@@config.server_ip} Port#{@@config.server_port}"}
    @@reports.summary.push(error_node)
    @@reports.output_error_report_summary()
    if @@browser_active then
      @@browser.goto("about:blank")
      @@browser.close
      sleep(5)
    end
    exit!(error["error_code"])
  end

  def self.shutdown
    self.shutdown_initializer()
    self.close_framework()
    self.generate_reports()
    return
  rescue Exception => e
    @@error_handling = Istock_Test_Suite_Error_Handling::Error_Handling.new()
    exception = Istock_Test_Suite_Error_Handling::ShutdownError.new(e.message,e.backtrace,e.inspect)
    error = @@error_handling.check_error(:exception=>exception,:test_name => self.inspect)
    y error["error_message"]
    error_node = Hash["error_type"=>"","error_message"=>""]
    error_node["error_type"] = "Startup Failure"
    error_node["error_message"] = error["error_message"] + {"Grid Node Info:" => "IP #{@@config.server_ip} Port#{@@config.server_port}"}
    @@reports.summary.push(error_node)
    @@reports.output_error_report_summary()
    @@reports.output_omit_report_summary()
    @@reports.output_time_report_summary()
    @@reports.output_memory_report_summary()
    if @@browser_active then
      sleep(2)
      @@browser.goto("about:blank")
      @@browser.close
      sleep(5)
    end
    exit!(error["error_code"])
  end

  def save_error_report
    @@current_fault = @@current_fault + 1
    error_info = @_result.faults.last
    error_node = Hash["error_type"=>"","error_message"=>""]
    case error_info.to_s
    when /\AFailure:/
      error_type = "failure"
      error_message = {
        "Test name" => error_info.test_name,
        "Error" => "Assertion Failure",
        "Message" => error_info.message,
        "Grid Node Info" => "IP #{@@config.server_ip} Port#{@@config.server_port}",
        "Location" => error_info.location
      }
    when /\AError:/
      if error_info.exception.inspect =~ /recycled\sobject/i then
        error_type = "recycled"
        error_message = {
          "Test name" => error_info.test_name,
          "Error" => "Test Recycled",
          "Message" => error_info.message,
          "Grid Node Info" => "IP #{@@config.server_ip} Port #{@@config.server_port}",
          "Location" => error_info.location
        }
      elsif error_info.exception.inspect =~ /TestTimeOutError/i then
        error_type = "timeout"
        error_message = {
          "Test name" => error_info.test_name,
          "Error" => "Test Timeout",
          "Message" => error_info.message,
          "Grid Node Info" => "IP #{@@config.server_ip} Port #{@@config.server_port}",
          "Location" => error_info.location
        }
      else
        error_type = "error"
        error_message = {
          "Test name" => error_info.test_name,
          "Error" => "Fatal Error"
        }
        if @@browser_on == true then
          if @@istock_browser != nil then
            error_message = error_message + {
              "URL" => @@browser.url,
              "Possible Reason" => @@site_functions.test_for_error,
              "Grid Node Info:" =>  " IP #{@@config.server_ip} Port#{@@config.server_port}"
            }
          end
        end
        error_message = error_message +{
          "Exception" =>error_info.exception.inspect,
          "Message" => error_info.exception.message,
          "Backtrace" => error_info.exception.backtrace
        }
      end
    when /\AOmission:/
      error_type = "omitted"
      error_message = {
        "Test name" => error_info.test_name,
        "Error" => "Test Omission",
        "Message" => error_info.message,
        "Grid Node Info" => "IP #{@@config.server_ip} Port#{@@config.server_port}",
        "Location" => error_info.location
      }
    end
    if @@browser_on == true then
      if @@istock_browser != nil then
        error_message = error_message + {
          "Browser Memory Used" => @@istock_browser.memory
        }
      end
    end
    error_node["error_type"] = error_type
    error_node["error_message"] = error_message
    @@reports.summary.push(error_node)
  end

  def save_time_report()
    @time_finish = Time.now
    @time_elapsed = @time_finish - @time_start
    puts "Time Elapsed for Test:#{@time_elapsed}\n\n"
    @@reports.test_time.push "#{self.method_name} : #{@time_elapsed}"
    @@reports.test_grid_node_info.push("IP #{@@config.server_ip} Port#{@@config.server_port}")
    @@reports.total_testsuite_time += @time_elapsed
  end

  def save_memory_report()
    if @@browser_on then
      pid = @@istock_browser.pid
      memory_used = @@istock_browser.memory
      @@reports.test_memory.push "#{self.method_name} : #{memory_used}"
      @@reports.test_grid_node_info.push("IP #{@@config.server_ip} Port#{@@config.server_port}")
    end
  end

  def self.initialize_reporting
    @@reports = nil
    @@reports = Istock_Test_Suite_Reports::Reports.new(@@config)
  rescue Exception => e
    @@error_handling = Istock_Test_Suite_Error_Handling::Error_Handling.new()
    exception = Istock_Test_Suite_Error_Handling::ReportingError.new(e.message,e.backtrace,e.inspect)
    error = @@error_handling.check_error(:exception=>exception,:test_name => self.inspect)
    y error["error_message"]
    exit!(error["error_code"])
  end


  def self.generate_reports
    puts "\n"
    @@reports.output_fail_report_summary()
    @@reports.output_error_report_summary()
    @@reports.output_timeout_report_summary()
    @@reports.output_omit_report_summary()
    @@reports.output_recycled_objects_report_summary()
    @@reports.output_time_report_summary()
    @@reports.output_memory_report_summary()
  end

  def setup_initializer()
  end

  def teardown_initializer()
  end

  def self.set_framework()
    @@suite = "test_suite"
  end

  def self.shutdown_initializer()
  end

  def self.startup_initializer()
  end
 
  def self.set_logging_level()
    if @@logging == nil then
      @@logging = @@config.logging
    end
    case @@logging
    when "debug"
      @@log.level = Logger::DEBUG
    when "warn"
      @@log.level = Logger::WARN
    when "error"
      @@log.level = Logger::ERROR
    when "fatal"
      @@log.level = Logger::FATAL
    when "info"
      @@log.level = Logger::INFO
    else
      @@log.level = Logger::DEBUG
    end
  rescue Exception => e
    @@error_handling = Istock_Test_Suite_Error_Handling::Error_Handling.new()
    exception = Istock_Test_Suite_Error_Handling::LoggingError.new(e.message,e.backtrace,e.inspect)
    error = @@error_handling.check_error(:exception=>exception,:test_name => self.inspect)
    y error["error_message"]
    error_node = Hash["error_type"=>"","error_message"=>""]
    error_node["error_type"] = "Logging Failure"
    error_node["error_message"] = error["error_message"]
    @@reports.summary.push(error_node)
    @@reports.output_error_report_summary()
    exit!(error["error_code"])
  end

  def self.load_config()
    case @@suite
    when "test_suite"
      @@config = Istock_Test_Suite_Config_Browser::Config.new($command_line_args)
    when "api"
      @@config = Istock_Test_Suite_Config_API::Config.new($command_line_args)
    else
      raise ArgumantError, ":config => #{@@suite}, is an invalid option"
    end
  rescue Exception => e
    @@error_handling = Istock_Test_Suite_Error_Handling::Error_Handling.new()
    exception = Istock_Test_Suite_Error_Handling::ConfigError.new(e.message,e.backtrace,e.inspect)
    error = @@error_handling.check_error(:exception=>exception,:test_name => self.inspect)
    y error["error_message"]
    exit!(error["error_code"])
  end
  
  def self.load_framework()
    if @@browser_on == nil then
      @@browser_on = @@config.browser_on
    end
    case @@suite
    when "test_suite"
      self.load_test_suite()
    when "api"
      self.load_api()
    else
      raise ArgumantError, ":config => #{@@suite}, is an invalid option"
    end
  rescue Exception => e
    @@error_handling = Istock_Test_Suite_Error_Handling::Error_Handling.new()
    if e.inspect =~ /(DRb::DRbConnError:)/ or e.to_s =~ /(Errno::ETIMEDOUT:)/ then
      e.to_s.match(/\/\/(.*):(\d+)/)
      server_ip = $1
      server_port = $2
      exception = Istock_Test_Suite_Error_Handling::GridError.new(e.message,e.backtrace,e.inspect)
      error = @@error_handling.check_error(:exception=>exception,:test_name => self.inspect)
      error_message = {
        "Test" => error["error_message"]["Test"],
        "Error" => error["error_message"]["Error"],
        "Server" => {
          "Host" => server_ip.to_s,
          "Port" => server_port.to_s
        },
        "Exception" => error["error_message"]["Exception"],
        "Message" => error["error_message"]["Message"],
        "Backtrace" => error["error_message"]["Backtrace"]
      }
    else
      exception = Istock_Test_Suite_Error_Handling::FrameworkError.new(e.message,e.backtrace,e.inspect)
      error = @@error_handling.check_error(:exception=>exception,:test_name => self.inspect)
      error_message = error["error_message"]
      y error_message
      error_node = Hash["error_type"=>"","error_message"=>""]
      error_node["error_type"] = "Framework Failure"
      error_node["error_message"] = error["error_message"] + {"Grid Node Info:" => "IP #{@@config.server_ip} Port#{@@config.server_port}"}
      @@reports.summary.push(error_node)
      @@reports.output_error_report_summary()
      if @@browser_active then
        @@browser.goto("about:blank")
        @@browser.close
        sleep(5)
      end
    end
    exit!(error["error_code"])
  end

  def self.close_framework()
    case @@suite
    when "test_suite"
      self.close_test_suite()
    when "api"
      self.close_api()
    else
      raise ArgumantError, ":config => #{@@suite}, is an invalid option"
    end
  end

  def istock_browser
    return(@@istock_browser)
  end

  def self.load_test_suite()
    puts "Loading Browser Framework"
    @@istock_browser = Istock_Browser_Layer::Istock_Browser.new(@@config)
    if @@istock_browser.success then
      @@browser = @@istock_browser.browser
      @@browser_active = @@istock_browser.browser_active
      @@browsertab = @@istock_browser.browsertab
      @@resource = @@istock_browser.resource_layer
      @@navigation = @@istock_browser.navigation_layer
      @@objects = @@istock_browser.object_layer
      @@file = @@istock_browser.data_layer.files
      @@data = @@istock_browser.data_layer
      @@log = @@istock_browser.logs.testlog
      @@constants = @@istock_browser.constants
      @@site_functions = @@istock_browser.site_functions
      @@databases = @@istock_browser.database_layer
      @@search_functions = @@site_functions
      @@user = @@istock_browser.data_layer.user_data
      @@user_info = @@istock_browser.data_layer.user_info_data
      @@cart = @@istock_browser.data_layer.cart_data
      @@cart_list = @@istock_browser.data_layer.cart_list_data
      @@cart_item = @@istock_browser.data_layer.cart_item_data
      @@httpwatch = @@istock_browser.httpwatch
      @@grid = @@istock_browser.grid
      if @@browser_on then
        if @@config.env != "qa" then
          @@site_functions.get_certificate()
        end
        @@site_functions.set_typing_speed(:zippy)
        @@navigation.goto(:page => "index")
      end
      @@test_priorities = Istock_Framework_Priorities::Istock_Priorities.new()
    else
      @@error_handling = Istock_Test_Suite_Error_Handling::Error_Handling.new()
      e = @@istock_browser.exception
      exception = Istock_Test_Suite_Error_Handling::FrameworkError.new(e.message,e.backtrace,e.inspect)
      error = @@error_handling.check_error(:exception=>exception,:test_name => self.inspect)
      error_message = error["error_message"]
      y error_message
      error_node = Hash["error_type"=>"","error_message"=>""]
      error_node["error_type"] = "Browser Failure"
      error_node["error_message"] = error["error_message"] + {"Grid Node Info:" => "IP #{@@config.server_ip} Port#{@@config.server_port}"}
      @@reports.summary.push(error_node)
      @@reports.output_error_report_summary()
      if @@istock_browser.browser_active then
        @@browser = @@istock_browser.browser
        @@browser.goto("about:blank")
        @@browser.close
        sleep(5)
      end
      exit!(error["error_code"])
    end
  end
 
  def self.load_api()
    puts "Loading API Framework"
    if @@browser_on then
      self.load_test_suite()
    else
      @@test_priorities = Istock_Framework_Priorities::Istock_Priorities.new()
    end
    @@istock_api = Istock_Api_Layer::Istock_Api.new(:env=>@@config.env)
    @@api_mongo = @@istock_api.api_mongo
    @@api_mysql = @@istock_api.api_mysql
    @@api_soap = @@istock_api.api_soap
    @@api_json = @@istock_api.api_json
    @@api_legacy = @@istock_api.api_legacy
    @@api_slave_delay = @@istock_api.api_slave_delay
    @@api_username =  @@istock_api.api_username
    @@api_password = @@istock_api.api_password
    @@api_key =  @@istock_api.api_key
    @@api_key_pp = @@istock_api.api_key_pp
    @@api_bluesky_key = @@istock_api.api_bluesky_key
    @@api_session_string = @@istock_api.api_session_string
    @@api_timestamp = @@istock_api.api_timestamp
    @@api_admin_membername = @@istock_api.api_admin_membername
    @@api_admin_password = @@istock_api.api_admin_password
    @@api_server_connection = @@istock_api.api_server_connection
    @@api_server_connection_opensearch = @@istock_api.api_server_connection_opensearch
    @@api_server_secure_connection = @@istock_api.api_server_secure_connection
    @@api_server_secure_uploads_connection = @@istock_api.api_server_secure_uploads_connection
    @@api_bluesky_server_connection = @@istock_api.api_bluesky_server_connection
    @@api_bluesky_server_secure_connection = @@istock_api.api_bluesky_server_secure_connection
    @@log = @@istock_api.api_logs.testlog
  end

  def self.close_test_suite()
    if @@browser_active then
      @@browser.goto("about:blank")
      @@browser.close()
      sleep(5)
    end
    @@databases.close_all()
  end

  def self.close_api()
    if @@browser_on then
      if @@browser_active then
        @@browser.goto("about:blank")
        @@browser.close()
        sleep(5)
      end
      @@databases.close_all()
    end
    @@api_mysql.close_all()
  end
end

