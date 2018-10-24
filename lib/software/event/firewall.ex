defmodule Helix.Software.Event.Firewall do

  import Hevent

  event Started do

    event_struct [:version, :gateway_id]
  end

  event Stopped do

    event_struct [:version, :gateway_id]
  end
end
