open Lwt.Infix

let src = Logs.Src.create "dns_mirage_client" ~doc:"effectful DNS client layer"
module Log = (val Logs.src_log src : Logs.LOG)

module Make (S : Mirage_stack_lwt.V4) = struct

  module Uflow : Udns_client_flow.S
    with type flow = S.TCPV4.flow
     and type stack = S.t
     and type (+'a,+'b) io = ('a, 'b) Lwt_result.t
           constraint 'b = [> `Msg of string]
     and type io_addr = Ipaddr.V4.t * int = struct
    type flow = S.TCPV4.flow
    type stack = S.t
    type io_addr = Ipaddr.V4.t * int
    type ns_addr = [`TCP | `UDP] * io_addr
    type (+'a,+'b) io = ('a, 'b) Lwt_result.t
      constraint 'b = [> `Msg of string]
    type t = {
      nameserver : ns_addr ;
      stack : stack ;
    }

    let create ?(nameserver = `TCP, (Ipaddr.V4.of_string_exn "91.239.100.100", 53)) stack =
      { nameserver ; stack }

    let nameserver { nameserver ; _ } = nameserver

    let map = Lwt_result.bind
    let resolve = Lwt_result.bind_result
    let lift = Lwt_result.lift

    let connect ?nameserver:ns t =
      let _proto, addr = match ns with None -> nameserver t | Some x -> x in
      S.TCPV4.create_connection (S.tcpv4 t.stack) addr >|= function
      | Error e ->
        Log.err (fun m -> m "error connecting to nameserver %a"
                    S.TCPV4.pp_error e) ;
        Error (`Msg "connect failure")
      | Ok flow -> Ok flow

    let recv flow =
      S.TCPV4.read flow >|= function
      | Error e -> Error (`Msg (Fmt.to_to_string S.TCPV4.pp_error e))
      | Ok (`Data cs) -> Ok cs
      | Ok `Eof -> Ok Cstruct.empty

    let send flow s =
      S.TCPV4.write flow s >|= function
      | Error e -> Error (`Msg (Fmt.to_to_string S.TCPV4.pp_write_error e))
      | Ok () -> Ok ()
  end

  include Udns_client_flow.Make(Uflow)

end

(*
type udns_ty = Udns_client

let config : 'a Mirage.impl =
  let open Mirage in
  impl @@ object inherit Mirage.base_configurable
    method module_name = "Udns_client"
    method name = "Udns_client"
    method ty : 'a typ = Type Udns_client
    method! packages : package list value =
      (Key.match_ Key.(value target) @@ begin function
          | `Unix -> [package "udns-client-unix"]
          | _ -> []
        end
      )
    method! deps = []
  end
*)
