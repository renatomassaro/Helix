defmodule HELM.Hardware.Controller.MotherboardTest do
  use ExUnit.Case

  alias HELM.Hardware.Controller.Motherboards, as: CtrlMobos

  test "create/1" do
    assert {:ok, _} = CtrlMobos.create()
  end

  describe "find/1" do
    test "success" do
      {:ok, mobo} = CtrlMobos.create()
      assert {:ok, ^mobo} = CtrlMobos.find(mobo.motherboard_id)
    end

    test "failure" do
      assert {:error, :notfound} = CtrlMobos.find("")
    end
  end

  test "delete/1 idempotency" do
    {:ok, mobo} = CtrlMobos.create()
    assert :ok = CtrlMobos.delete(mobo.motherboard_id)
    assert :ok = CtrlMobos.delete(mobo.motherboard_id)
  end
end