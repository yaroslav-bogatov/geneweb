(* $Id: srcfile.mli,v 5.4 2006-11-23 18:54:12 ddr Exp $ *)
(* Copyright (c) 1998-2006 INRIA *)

open Gwdb;
open Config;

value print : config -> base -> string -> unit;
value print_source : config -> base -> string -> unit;
value print_start : config -> base -> unit;
value incr_welcome_counter : config -> option (int * int * string);
value incr_request_counter : config -> option (int * int * string);

value print_lexicon : config -> base -> unit;

value adm_file : string -> string;
value source_file_name : config -> string -> string;
