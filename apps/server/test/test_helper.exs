{:ok, _} = Application.ensure_all_started(:helf_broker)
{:ok, _} = Application.ensure_all_started(:hardware)
{:ok, _} = Application.ensure_all_started(:server)
ExUnit.start()
