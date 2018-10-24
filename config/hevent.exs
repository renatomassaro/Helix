use Mix.Config

config :hevent, :triggers,
  [
    Helix.Event.Trigger.Loggable,
    Helix.Event.Trigger.Publishable,
    Helix.Event.Trigger.Notificable,
    Helix.Event.Trigger.Listenable
  ]

config :hevent, :events,
  [
    # Account
    Helix.Account.Event.Account.Created,
    Helix.Account.Event.Account.Verified,

    # Client
    Helix.Client.Event.Action.Performed,

    # Entity
    Helix.Entity.Event.Entity.Created,

    # Network
    Helix.Network.Event.Bounce.Created,
    Helix.Network.Event.Bounce.CreateFailed,
    Helix.Network.Event.Bounce.Removed,
    Helix.Network.Event.Bounce.RemoveFailed,
    Helix.Network.Event.Bounce.Updated,
    Helix.Network.Event.Bounce.UpdateFailed,
    Helix.Network.Event.Connection.Closed,
    Helix.Network.Event.Connection.Started,

    # Notification
    Helix.Notification.Event.Notification.Added,
    Helix.Notification.Event.Notification.Read,

    # Log
    Helix.Log.Event.Forge.Processed,
    Helix.Log.Event.Log.Created,
    Helix.Log.Event.Log.Created,
    Helix.Log.Event.Log.Destroyed,
    Helix.Log.Event.Log.Recovered,
    Helix.Log.Event.Log.Revised,
    Helix.Log.Event.Recover.Processed,

    # Process
    Helix.Process.Event.Process.Created,
    Helix.Process.Event.Process.Completed,
    Helix.Process.Event.Process.Killed,
    Helix.Process.Event.Process.Signaled,
    Helix.Process.Event.TOP.BringMeToLife,
    Helix.Process.Event.TOP.Recalcado,

    # Server
    Helix.Server.Event.Motherboard.Updated,
    Helix.Server.Event.Motherboard.UpdateFailed,
    Helix.Server.Event.Server.Password.Acquired,
    Helix.Server.Event.Server.Joined,

    # Software
    Helix.Software.Event.Cracker.Overflow.Processed,
    Helix.Software.Event.Cracker.Bruteforce.Processed,
    Helix.Software.Event.Cracker.Bruteforce.Failed,
    Helix.Software.Event.File.Added,
    Helix.Software.Event.File.Deleted,
    Helix.Software.Event.File.Downloaded,
    Helix.Software.Event.File.DownloadFailed,
    Helix.Software.Event.File.Install.Processed,
    Helix.Software.Event.File.Transfer.Processed,
    Helix.Software.Event.File.Transfer.Aborted,
    Helix.Software.Event.File.Uploaded,
    Helix.Software.Event.File.UploadFailed,
    Helix.Software.Event.File.Added,
    Helix.Software.Event.File.Added,
    Helix.Software.Event.Virus.Collect.Processed,
    Helix.Software.Event.Virus.Collected,
    Helix.Software.Event.Virus.Installed,
    Helix.Software.Event.Virus.InstallFailed,
    Helix.Software.Event.Virus.InstallFailed,
    Helix.Software.Event.Virus.InstallFailed,
    Helix.Software.Event.Virus.InstallFailed,
    Helix.Software.Event.Virus.InstallFailed,
    Helix.Software.Event.Virus.InstallFailed,
    Helix.Software.Event.Virus.InstallFailed,

    # Story
    Helix.Story.Event.Email.Sent,
    Helix.Story.Event.Reply.Sent,
    Helix.Story.Event.Step.ActionRequested,
    Helix.Story.Event.Step.Proceeded,
    Helix.Story.Event.Step.Restarted,

    # Universe.Bank
    Helix.Universe.Bank.Event.Bank.Account.Login,
    Helix.Universe.Bank.Event.Bank.Account.Updated,
    Helix.Universe.Bank.Event.Bank.Account.Password.Revealed,
    Helix.Universe.Bank.Event.Bank.Account.Token.Acquired,
    Helix.Universe.Bank.Event.Bank.Transfer.Processed,
    Helix.Universe.Bank.Event.Bank.Transfer.Aborted,
    Helix.Universe.Bank.Event.RevealPassword.Processed
  ]

config :hevent, :handlers,
  [
    # Account
    Helix.Account.Event.Handler.Account,

    # Entity
    Helix.Entity.Event.Handler.Database,

    # Network
    Helix.Network.Event.Handler.Connection,
    Helix.Network.Event.Handler.Tunnel,

    # Log
    Helix.Log.Event.Handler.Log,

    # Process
    Helix.Process.Event.Handler.Process,
    Helix.Process.Event.Handler.TOP,

    # Software
    Helix.Software.Event.Handler.Cracker,
    Helix.Software.Event.Handler.File.Transfer,
    Helix.Software.Event.Handler.Filesystem,
    Helix.Software.Event.Handler.Virus,

    # Story
    Helix.Story.Event.Handler.Story,
    Helix.Story.Event.Handler.Manager,

    # Universe.Bank
    Helix.Universe.Bank.Event.Handler.Bank.Account,
    Helix.Universe.Bank.Event.Handler.Bank.Transfer
  ]
