defmodule NXRedirect.DNSHeader do
  @moduledoc """
  Provides the "header" function to parse the header of a DNS message.
  """

  defstruct id:      <<>>,
            qr:      <<>>,
            opcode:  <<>>,
            aa:      <<>>,
            tc:      <<>>,
            rd:      <<>>,
            ra:      <<>>,
            z:       <<>>,
            rcode:   <<>>,
            qdcnt:   <<>>,
            ancnt:   <<>>,
            nscnt:   <<>>,
            arcnt:   <<>>

  @doc """
  Parse the header of a DNS message
  """
  def header(packet) do
    <<
      id        :: bytes - size(2),
      qr        :: bits - size(1),
      opcode    :: bits - size(4),
      aa        :: bits - size(1),
      tc        :: bits - size(1),
      rd        :: bits - size(1),
      ra        :: bits - size(1),
      z         :: bits - size(3),
      rcode     :: bits - size(4),
      qdcnt     :: unsigned - integer - size(16),
      ancnt     :: unsigned - integer - size(16),
      nscnt     :: unsigned - integer - size(16),
      arcnt     :: unsigned - integer - size(16),
      _payload  :: binary
    >> = packet
    %NXRedirect.DNSHeader{
      id:     id,
      qr:     qr,
      opcode: opcode,
      aa:     aa,
      tc:     tc,
      rd:     rd,
      ra:     ra,
      z:      z,
      rcode:  rcode,
      qdcnt:  qdcnt,
      ancnt:  ancnt,
      nscnt:  nscnt,
      arcnt:  arcnt
    }
  end
end
