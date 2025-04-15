#
# Copied from Hashicorp's Vault ruby gem, source is licensed under MPL2.0
#
# https://github.com/hashicorp/vault-ruby/blob/master/spec/support/vault_server.rb
#
#
#
require 'open-uri'
require 'singleton'
require 'timeout'
require 'tempfile'
require 'vault'

module RSpec
  class VaultServer
    include Singleton

    TOKEN_PATH = File.expand_path("~/.vault-token").freeze
    TOKEN_PATH_BKUP = "#{TOKEN_PATH}.bak".freeze

    def self.method_missing(m, *args, &block)
      self.instance.public_send(m, *args, &block)
    end

    attr_reader :token
    attr_reader :unseal_token

    def initialize
      # If there is already a vault-token, we need to move it so we do not
      # clobber!
      if File.exist?(TOKEN_PATH)
        FileUtils.mv(TOKEN_PATH, TOKEN_PATH_BKUP)
        at_exit do
          FileUtils.mv(TOKEN_PATH_BKUP, TOKEN_PATH)
        end
      end

      io = Tempfile.new("vault-server")
      pid = Process.spawn({}, "vault server -dev -dev-listen-address=#{host}:#{port}", out: io.to_i, err: io.to_i)

      at_exit do
        Process.kill("INT", pid)
        Process.waitpid2(pid)

        io.close
        io.unlink
      end

      wait_for_ready do
        @token = File.read(TOKEN_PATH)

        output = ""
        while
          io.rewind
          output = io.read
          break if !output.empty?
        end

        if output.match(/Unseal Key.*: (.+)/)
          @unseal_token = $1.strip
        else
          raise "Vault did not return an unseal token!"
        end
      end
    end

    def address
      "http://#{host}:#{port}"
    end

    def host
      '127.0.0.1'
    end

    def port
      8200 + ENV.fetch('TEST_ENV_NUMBER', 0).to_i
    end

    def wait_for_ready(&block)
      Timeout.timeout(10) do
        while !File.exist?(TOKEN_PATH)
          sleep(0.25)
        end
      end

      yield
    rescue Timeout::Error
      raise "Vault did not start in 10 seconds!"
    end
  end
end
