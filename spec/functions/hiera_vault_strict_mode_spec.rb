# frozen_string_literal: true

# Specs for strict_mode: when true, Vault errors (e.g. invalid token, permission denied) are raised
# as Puppet::DataBinding::LookupError; when false or unset, they are logged and lookup continues (not_found).

require 'spec_helper'
require 'support/vault_server'
require 'puppet/functions/hiera_vault'

describe FakeFunction do
  let :function do
    described_class.new
  end

  let :context do
    ctx = instance_double('Puppet::LookupContext')
    allow(ctx).to receive(:cache_has_key).and_return(false)
    if ENV['DEBUG']
      allow(ctx).to receive(:explain) { |&block| puts(block.call) }
    else
      allow(ctx).to receive(:explain).and_return(:nil)
    end
    allow(ctx).to receive(:not_found)
    allow(ctx).to receive(:cache).with(String, anything) do |_, val|
      val
    end
    allow(ctx).to receive(:interpolate).with(anything) do |val|
      val
    end
    ctx
  end

  let :vault_options do
    {
      'address' => RSpec::VaultServer.address,
      'token' => RSpec::VaultServer.token,
      'mounts' => {
        'puppet' => [
          'common'
        ]
      }
    }
  end

  def vault_test_client
    Vault::Client.new(
      address: RSpec::VaultServer.address,
      token: RSpec::VaultServer.token
    )
  end

  describe '#lookup_key' do
    context 'accessing vault' do
      context 'when vault is unsealed' do
        context 'configuring vault' do
          let :context do
            ctx = instance_double('Puppet::LookupContext')
            allow(ctx).to receive(:cache_has_key).and_return(false)
            allow(ctx).to receive(:explain) { |&block| puts(block.call) }
            allow(ctx).to receive(:not_found)
            allow(ctx).to receive(:cache).with(String, anything) do |_, val|
              val
            end
            allow(ctx).to receive(:interpolate).with(anything) do |val|
              val
            end
            ctx
          end

          # strict_mode true + bad token → must raise LookupError with message including "strict_mode is true so raising as error".
          it 'throws error when file token is not valid and strict_mode is set to true' do
            vault_token_tmpfile = Tempfile.open('w')
            vault_token_tmpfile.puts('not-valid-token')
            vault_token_tmpfile.close
            expect do
              function.lookup_key('test_key', vault_options.merge({ 'token' => vault_token_tmpfile.path, 'strict_mode' => true }), context)
            end.to raise_error(Puppet::DataBinding::LookupError, %r{Could not read secret puppet/common:.*permission denied.*invalid token.*strict_mode is true so raising as error}m)
          end

          # strict_mode false → no exception; error is only sent to explain (stdout), and no "strict_mode... raising" in message.
          it 'does not throw error when file token is not valid and strict_mode is set to false' do
            vault_token_tmpfile = Tempfile.open('w')
            vault_token_tmpfile.puts('not-valid-token')
            vault_token_tmpfile.close
            expectation = expect { function.lookup_key('test_key', vault_options.merge({ 'token' => vault_token_tmpfile.path, 'strict_mode' => false }), context) }
            expectation.not_to raise_error
            expectation.to output(%r{\[hiera-vault\] Could not read secret puppet/common: 2 errors occurred:.*permission denied.*invalid token}m).to_stdout
            expectation.not_to output(%r{strict_mode is true so raising as error}).to_stdout
          end

          # strict_mode unset defaults to false behavior: no raise, error only in explain output.
          it 'does not throw error when file token is not valid and strict_mode is not set' do
            vault_token_tmpfile = Tempfile.open('w')
            vault_token_tmpfile.puts('not-valid-token')
            vault_token_tmpfile.close
            expectation = expect { function.lookup_key('test_key', vault_options.merge({ 'token' => vault_token_tmpfile.path }), context) }
            expectation.not_to raise_error
            expectation.to output(%r{\[hiera-vault\] Could not read secret puppet/common: 2 errors occurred:.*permission denied.*invalid token}m).to_stdout
            expectation.not_to output(%r{strict_mode is true so raising as error}).to_stdout
          end
        end
      end
    end
  end
end
