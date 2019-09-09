defmodule Helix.Test.Story.Vars do
  @moduledoc """
  This helper holds storyline-wide IDs and pointers. Helpful to avoiding
  hard-coding stuff on the tests!
  """

  @vars %{
    contact: %{
      friend: "friend"
    },
    tutorial: %{
      welcome: %{
        contact: "friend",
        name: "welcome",
        next: "download_cracker",
        msg1: "c_welcome1",
        msg2: "p_welcome1",
        msg3: "c_welcome2",
        msg4: "c_welcome3",
        msg5: "c_welcome4",
      },
      dl_crc: %{
        contact: "friend",
        name: "download_cracker",
        next: "nasty_virus",
        msg1: "download_cracker1",
        msg2: "about_that",
        msg3: "yeah_right",
        msg4: "downloaded",
        msg5: "nothing_now"
      },
      nasty: %{
        contact: "friend",
        name: "nasty_virus",
        next: "IDONTKNOW",
        msg1: "nasty_virus1",
        msg2: "nasty_virus2",
        msg3: "punks1",
        msg4: "punks2",
        msg5: "punks3",
        msg6: "dlayd_much1",
        msg7: "dlayd_much2",
        msg8: "dlayd_much3",
        msg9: "dlayd_much4",
        msg10: "noice",
        msg11: "nasty_virus3",
        msg12: "virus_spotted1",
        msg13: "virus_spotted2",
        msg14: "pointless_convo1",
        msg15: "pointless_convo2",
        msg16: "pointless_convo3",
        msg17: "pointless_convo4",
        msg18: "pointless_convo5"
      }
    }
  }

  def vars,
    do: @vars
end
