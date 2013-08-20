require_relative 'spec_helper'

describe 'test that requires CF components', type: :integration, :components => [:nats, :ccng] do
  include CcngClient

  it 'start nats and ccng as required' do
    component!(:nats).should be
    ccng_get('/v2/services').should be
  end
end
