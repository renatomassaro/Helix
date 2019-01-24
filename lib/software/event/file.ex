defmodule Helix.Software.Event.File do

  import Hevent

  event Added do
    @moduledoc """
    FileAddedEvent is fired when a new file is added to the filesystem. Most of
    the times is called as a result of FileDownloadedEvent or FileUploadedEvent.
    """

    alias Helix.Server.Model.Server
    alias Helix.Software.Model.File

    @type t ::
      %__MODULE__{
        file: File.t,
        server_id: Server.id
      }

    event_struct [:file, :server_id]

    @spec new(File.t, Server.id) ::
      t
    def new(file = %File{}, server_id = %Server.ID{}) do
      %__MODULE__{
        file: file,
        server_id: server_id
      }
    end

    trigger Publishable do
      @moduledoc """
      Publishes the event to the Client, so it can display the new file.
      """

      use Helix.Event.Trigger.Publishable.Macros

      alias Helix.Software.Public.Index, as: SoftwareIndex

      event_name :file_added

      def generate_payload(event) do
        data = %{
          file: SoftwareIndex.render_file(event.file)
        }

        {:ok, data}
      end

      def whom_to_publish(event),
        do: %{server: [event.server_id]}
    end
  end

  event Deleted do
    @moduledoc """
    FileDeletedEvent is fired when a file has been deleted on the filesystem.
    Most of the times is called as a result of FileDeleteProcessedEvent
    """

    alias Helix.Server.Model.Server
    alias Helix.Software.Model.File

    @type t ::
      %__MODULE__{
        file_id: File.id,
        server_id: Server.id
      }

    event_struct [:file_id, :server_id]

    @spec new(File.id, Server.id) ::
      t
    def new(file_id = %File.ID{}, server_id = %Server.ID{}) do
      %__MODULE__{
        file_id: file_id,
        server_id: server_id
      }
    end

    trigger Publishable do
      @moduledoc """
      Publishes the event to the Client, so it can remove the deleted file.
      """

      use Helix.Event.Trigger.Publishable.Macros

      event_name :file_deleted

      def generate_payload(event) do
        data = %{
          file_id: to_string(event.file_id)
        }

        {:ok, data}
      end

      def whom_to_publish(event),
        do: %{server: [event.server_id]}
    end

    trigger Listenable do

      @doc false
      def get_objects(event),
        do: [event.file_id]
    end
  end

  event Downloaded do
    @moduledoc """
    FileDownloadedEvent is fired when a FileTransfer process of type `download`
    has finished successfully, in which case a new file has been transferred to
    the corresponding server.
    """

    alias Helix.Entity.Model.Entity
    alias Helix.Network.Model.Network
    alias Helix.Server.Model.Server
    alias Helix.Software.Model.File
    alias Helix.Software.Model.Storage

    alias Helix.Software.Event.File.Transfer.Processed,
      as: FileTransferProcessedEvent

    @type t :: %__MODULE__{
      entity_id: Entity.id,
      to_server_id: Server.id,
      from_server_id: Server.id,
      file: File.t,
      to_storage_id: Storage.id,
      network_id: Network.id,
      connection_type: :ftp | :public_ftp,
      source_file_id: File.id
    }

    event_struct [
      :entity_id,
      :to_server_id,
      :from_server_id,
      :file,
      :to_storage_id,
      :network_id,
      :connection_type,
      :source_file_id
    ]

    @spec new(FileTransferProcessedEvent.t, File.t) ::
      t
    def new(
      transfer = %FileTransferProcessedEvent{type: :download},
      file = %File{})
    do
      %__MODULE__{
        entity_id: transfer.entity_id,
        to_server_id: transfer.to_server_id,
        from_server_id: transfer.from_server_id,
        to_storage_id: transfer.to_storage_id,
        network_id: transfer.network_id,
        connection_type: transfer.connection_type,
        file: file,
        source_file_id: transfer.file_id,
      }
    end

    trigger Publishable do
      @moduledoc """
      Publishes to the Client that a file has been downloaded.
      """

      use Helix.Event.Trigger.Publishable.Macros

      alias Helix.Software.Public.Index, as: SoftwareIndex

      event_name :file_downloaded

      def generate_payload(event) do
        data = %{
          file: SoftwareIndex.render_file(event.file)
        }

        {:ok, data}
      end

      @doc """
      We only publish to the "downloader" server.
      """
      def whom_to_publish(event),
        do: %{server: event.to_server_id}
    end

    trigger Loggable do

      alias Helix.Event.Loggable.Utils, as: LoggableUtils

      @doc """
      Generates a log entry when a File has been downloaded from a Public FTP
      server.

      In this case, to protect the downloader's identity and honor the "public"
      part, we censor the downloader's IP address, which will be saved on the
      PublicFTP host server, but with 5 digits censored.

      On the other hand, the host server IP address is not censored, and will be
      saved fully on the downloader's server.
      """
      def log_map(event = %{connection_type: :public_ftp}) do
        file = LoggableUtils.get_file_name(event.file)

        %{
          event: event,
          entity_id: event.entity_id,
          gateway_id: event.to_server_id,
          endpoint_id: event.from_server_id,
          network_id: event.network_id,
          type_gateway: :pftp_file_download_gateway,
          data_gateway: %{ip: "$first_ip"},
          type_endpoint: :pftp_file_download_endpoint,
          data_endpoint: %{ip: "$last_ip"},
          data_both: %{network_id: event.network_id, file_name: file},
          opts: %{skip_bounce: true, censor_last: true}
        }
      end

      @doc """
      Generates a log entry when a File has been downloaded from a server.

        Gateway: "localhost downloaded file $file_name from $first_ip"
        Endpoint: "$last_ip downloaded file $file_name from localhost"
      """
      def log_map(event = %{connection_type: :ftp}) do
        file_name = LoggableUtils.get_file_name(event.file)

        %{
          event: event,
          entity_id: event.entity_id,
          gateway_id: event.to_server_id,
          endpoint_id: event.from_server_id,
          network_id: event.network_id,
          type_gateway: :file_download_gateway,
          data_gateway: %{ip: "$first_ip"},
          type_endpoint: :file_download_endpoint,
          data_endpoint: %{ip: "$last_ip"},
          data_both: %{network_id: event.network_id, file_name: file_name}
        }
      end
    end

    trigger Notificable do
      @moduledoc """
      # TODO: Move documentation below to somewhere else.
      # Mirrored Notifications

      The `FileDownloadedNotification` will notify the user that a download has
      completed. It has a peculiarity from a usability standpoint: it is what
      we call a *Mirrored Notification*.

      Suppose a player has just downloaded a file. In which server - the one
      he downloaded from, or the one he downloaded to - should we display the
      notification?

      We've decided to shown on *both* servers, however if the player reads the
      notification on one server, the other one is automatically marked as read.

      The implementation of this Mirrored Notification is made exclusively on
      the client, however I'm explaining it here for the sake of documentation.

      Note several other notifications may be mirrored, including the opposite
      of `FileDownloadedNotification`: `FileUploadedNotification`.
      """

      use Helix.Event.Trigger.Notificable.Macros

      @class :server
      @code :file_downloaded

      def whom_to_notify(event),
        do: %{account_id: event.entity_id, server_id: event.to_server_id}
    end

    trigger Listenable do

      @doc false
      def get_objects(event),
        do: [event.source_file_id]
    end
  end

  event DownloadFailed do
    @moduledoc """
    FileDownloadFailedEvent is fired when a FileTransfer process of type
    `download` has finished with problems, in which case the transfer of the
    file was NOT successful.
    """

    alias Helix.Entity.Model.Entity
    alias Helix.Network.Model.Network
    alias Helix.Server.Model.Server

    alias Helix.Software.Event.File.Transfer.Processed,
      as: FileTransferProcessedEvent

    @type reason ::
      :no_space_left
      | :file_not_found
      | :unknown

    @type t :: %__MODULE__{
      reason: reason,
      entity_id: Entity.id,
      to_server_id: Server.id,
      from_server_id: Server.id,
      network_id: Network.id,
      connection_type: :ftp | :public_ftp
    }

    event_struct [
      :reason,
      :entity_id,
      :to_server_id,
      :from_server_id,
      :network_id,
      :connection_type
    ]

    @spec new(FileTransferProcessedEvent.t, reason) ::
      t
    def new(transfer = %FileTransferProcessedEvent{type: :download}, reason) do
      %__MODULE__{
        entity_id: transfer.entity_id,
        to_server_id: transfer.to_server_id,
        from_server_id: transfer.from_server_id,
        network_id: transfer.network_id,
        connection_type: transfer.connection_type,
        reason: reason
      }
    end
  end

  event Uploaded do
    @moduledoc """
    FileUploadedEvent is fired when a FileTransfer process of type `upload` has
    finished successfully, in which case a new file has been transferred to the
    corresponding server.
    """

    alias Helix.Entity.Model.Entity
    alias Helix.Network.Model.Network
    alias Helix.Server.Model.Server
    alias Helix.Software.Model.File
    alias Helix.Software.Model.Storage

    alias Helix.Software.Event.File.Transfer.Processed,
      as: FileTransferProcessedEvent

    @type t :: %__MODULE__{
      entity_id: Entity.id,
      to_server_id: Server.id,
      from_server_id: Server.id,
      file: File.t,
      to_storage_id: Storage.id,
      network_id: Network.id,
      connection_type: :ftp | :public_ftp
    }

    event_struct [
      :entity_id,
      :to_server_id,
      :from_server_id,
      :file,
      :to_storage_id,
      :network_id,
      :connection_type
    ]

    @spec new(FileTransferProcessedEvent.t, File.t) ::
      t
    def new(
      transfer = %FileTransferProcessedEvent{type: :upload},
      file = %File{})
    do
      %__MODULE__{
        entity_id: transfer.entity_id,
        to_server_id: transfer.to_server_id,
        from_server_id: transfer.from_server_id,
        to_storage_id: transfer.to_storage_id,
        network_id: transfer.network_id,
        file: file,
        connection_type: transfer.connection_type,
      }
    end

    trigger Publishable do
      @moduledoc """
      Publishes to the Client that a file has been uploaded.
      """

      use Helix.Event.Trigger.Publishable.Macros

      alias Helix.Software.Public.Index, as: SoftwareIndex

      event_name :file_uploaded

      def generate_payload(event) do
        data = %{
          file: SoftwareIndex.render_file(event.file)
        }

        {:ok, data}
      end

      @doc """
      We only publish to the "uploader" server.
      """
      def whom_to_publish(event),
        do: %{server: event.from_server_id}
    end

    trigger Loggable do
      @doc """
      Generates a log entry when a File has been uploaded to a server.

        Gateway: "localhost uploaded file $file_name to $first_ip"
        Endpoint: "$last_ip uploaded file $file_name to localhost"
      """

      alias Helix.Event.Loggable.Utils, as: LoggableUtils

      def log_map(event) do
        file_name = LoggableUtils.get_file_name(event.file)

        %{
          event: event,
          entity_id: event.entity_id,
          gateway_id: event.from_server_id,
          endpoint_id: event.to_server_id,
          network_id: event.network_id,
          type_gateway: :file_upload_gateway,
          data_gateway: %{ip: "$first_ip"},
          type_endpoint: :file_upload_endpoint,
          data_endpoint: %{ip: "$last_ip"},
          data_both: %{network_id: event.network_id, file_name: file_name}
        }
      end
    end

    trigger Notificable do
      use Helix.Event.Trigger.Notificable.Macros

      @class :server
      @code :file_uploaded

      # Mirrored notification
      def whom_to_notify(event),
        do: %{account_id: event.entity_id, server_id: event.to_server_id}
    end
  end

  event UploadFailed do
    @moduledoc """
    FileUploadFailedEvent is fired when a FileTransfer process of type `upload`
    has finished with problems, in which case the transfer of the file was NOT
    successful.
    """

    alias Helix.Entity.Model.Entity
    alias Helix.Network.Model.Network
    alias Helix.Server.Model.Server

    alias Helix.Software.Event.File.Transfer.Processed,
      as: FileTransferProcessedEvent

    @type reason ::
      :no_space_left
      | :file_not_found
      | :unknown

    @type t :: %__MODULE__{
      reason: reason,
      entity_id: Entity.id,
      to_server_id: Server.id,
      from_server_id: Server.id,
      network_id: Network.id
    }

    event_struct [
      :reason,
      :entity_id,
      :to_server_id,
      :from_server_id,
      :network_id
    ]

    @spec new(FileTransferProcessedEvent.t, reason) ::
      t
    def new(transfer = %FileTransferProcessedEvent{type: :upload}, reason) do
      %__MODULE__{
        entity_id: transfer.entity_id,
        to_server_id: transfer.to_server_id,
        from_server_id: transfer.from_server_id,
        network_id: transfer.network_id,
        reason: reason
      }
    end
  end
end
