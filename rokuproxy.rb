#!/usr/bin/env ruby

# see
# https://developer.roku.com/docs/developer-program/debugging/external-control-api.md

require 'webrick'
require 'nokogiri'
require 'net/http'
require 'erb'
require 'pry'
require 'forwardable'

ROKU_PORT = 8060
ROKU_IP = '192.168.1.15'

class Cache
  extend Forwardable
  include Singleton

  def initialize
    @cache = { }
  end

  def_delegators :@cache, :[], :[]=
end

def red(msg)
  "\033[31m#{msg}\033[0m"
end


def get(path)
  cache = Cache.instance
  path = "/#{path}" unless path[0] == '/'
  puts red(path) unless cache[path]
  cache[path] ||= Net::HTTP.get(ROKU_IP, path, ROKU_PORT)
end

def post(path)
  path = "/#{path}" unless path[0] == '/'
  puts red(path)
  Net::HTTP.start(ROKU_IP, ROKU_PORT) do |http|
    request = Net::HTTP::Post.new path
    response = http.request request
    response.body
  end
end

def load_apps
  apps = { }

  doc = Nokogiri.XML(get('/query/apps'))
  doc.search('app').sort_by{|a| a.text}.each do |app|
    apps[app['id']] = app.text
  end

  apps
end

def do_index
  @apps = load_apps
  @keys = {
    home:          "Home",
    select:        "OK",
    _1:            nil,
    left:          "\u21e6",
    up:            "\u21e7",
    right:         "\u21e8",
    down:          "\u21e9",
    _2:            nil,
    rev:           "\u21E4",
    play:          "\u25B7",
    fwd:           "\u21E5",
    _3:            nil,
    back:          "\u21A9",
    instantreplay: "Replay",
    info:          "Info",
    _4:            nil,
    backspace:     "\u232B",
    enter:         "Enter",
    search:        "Search",
    # Only on a roku tv:
    # _5:            nil,
    # volumeup:      "\u2b06",
    # volumemute:    "Mute",
    # volumedown:    "\u2b07",
    # poweroff:      "Off",
  }

  ERB.new(File.read('index.erb')).result
end

server = WEBrick::HTTPServer.new(
  BindAddress: '0.0.0.0',
  Port: 8000,
  AccessLog: [],
)

server.mount_proc '/' do |req, res|
  case req.path
  when '/'
    res.body = do_index
  else
    if req.path.start_with?('/keypress', '/launch')
      post(req.path)
      res.body = do_index
    else
      res.body = get(req.path)
    end
  end
end

server.start
