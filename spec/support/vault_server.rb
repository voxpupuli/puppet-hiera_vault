#
# Copied from Hashicorp's Vault ruby gem, source is licensed under MPL2.0
#
# https://github.com/hashicorp/vault-ruby/blob/master/spec/support/vault_server.rb
#
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

require 'open-uri'
require 'singleton'
require 'timeout'
require 'tempfile'

module RSpec
  class VaultServer
    include Singleton

    TOKEN_PATH = File.expand_path('~/.vault-token').freeze

    def self.method_missing(m, *args, &block)
      instance.public_send(m, *args, &block)
    end

    attr_reader :token, :unseal_token

    def initialize
      # If there is already a vault-token, we need to move it so we do not
      # clobber!
      FileUtils.rm_rf(TOKEN_PATH)

      io = Tempfile.new("vault-server")
      pid = Process.spawn({}, "vault server -dev -dev-listen-address=#{host}:#{port}", out: io.to_i, err: io.to_i)

      at_exit do
        Process.kill('INT', pid)
        Process.waitpid2(pid)

        io.close
        io.unlink
      end
      wait_for_ready
      puts 'vault server is ready'
      # sleep to get unseal token
      sleep 5

      @token = 'root'

      output = ''
      while io.rewind
        output = io.read
        break unless output.empty?
      end

      raise "Vault did not return an unseal token! Output is: #{output}" unless output.match(%r{Unseal Key.*: (.+)})

      @unseal_token = ::Regexp.last_match(1).strip
      puts "unseal token is: #{@unseal_token}"
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

    def wait_for_ready
      uri = URI("#{address}/v1/sys/health")
      Timeout.timeout(15) do
        loop do
          begin
            response = Net::HTTP.get_response(uri)
            return true if response.code != 200
          rescue Errno::ECONNREFUSED
            puts 'waiting for vault to start'
          end
          sleep 2
        end
      end
    rescue Timeout::Error
      raise TimeoutError, 'Timed out waiting for vault health check'
    end
  end
end
