(* camlp4r ./pa_html.cmo *)
(* $Id: updateInd.ml,v 4.29 2005-05-27 04:50:35 ddr Exp $ *)
(* Copyright (c) 1998-2005 INRIA *)

open Config;
open Def;
open Util;
open Gutil;
open TemplAst;

value bogus_person_index = Adef.iper_of_int (-1);

value string_person_of base p =
  let fp ip =
    let p = poi base ip in
    (sou base p.first_name, sou base p.surname, p.occ, Update.Link, "")
  in
  Gutil.map_person_ps fp (sou base) p
;

(* Interpretation of template file 'updind.txt' *)

type env =
  [ Vstring of string
  | Vfun of list string and list ast
  | Vint of int
  | Vnone ]
;

value get_env v env = try List.assoc v env with [ Not_found -> Vnone ];

value extract_var sini s =
  let len = String.length sini in
  if String.length s > len && String.sub s 0 (String.length sini) = sini then
    String.sub s len (String.length s - len)
  else ""
;

value obsolete_list = ref [];

value obsolete version var new_var r =
  if List.mem var obsolete_list.val then r
  else IFDEF UNIX THEN do {
    Printf.eprintf "*** <W> updind.txt: \"%s\" obsolete since v%s%s\n"
      var version
      (if new_var = "" then "" else "; rather use \"" ^ new_var ^ "\"");
    flush stderr;
    obsolete_list.val := [var :: obsolete_list.val];
    r
  }
  ELSE r END
;

value bool_val x = VVbool x;
value str_val x = VVstring x;

value rec eval_var conf base env p loc =
  fun
  [ ["alias"] -> eval_string_env "alias" env
  | ["acc_if_titles"] -> bool_val (p.access = IfTitles)
  | ["acc_private"] -> bool_val (p.access = Private)
  | ["acc_public"] -> bool_val (p.access = Public)
  | ["bapt_place"] -> str_val (quote_escaped p.baptism_place)
  | ["bapt_src"] -> str_val (quote_escaped p.baptism_src)
  | ["birth"; s] -> eval_date_var (Adef.od_of_codate p.birth) s
  | ["birth_place"] -> str_val (quote_escaped p.birth_place)
  | ["birth_src"] -> str_val (quote_escaped p.birth_src)
  | ["bapt"; s] -> eval_date_var (Adef.od_of_codate p.baptism) s
  | ["bt_buried"] ->
        bool_val (match p.burial with [ Buried _ -> True | _ -> False ])
  | ["bt_cremated"] ->
        bool_val (match p.burial with [ Cremated _ -> True | _ -> False ])
  | ["bt_unknown_burial"] -> bool_val (p.burial = UnknownBurial)
  | ["burial"; s] ->
      let od =
        match p.burial with
        [ Buried cod -> Adef.od_of_codate cod
        | Cremated cod -> Adef.od_of_codate cod
        | _ -> None ]
      in
      eval_date_var od s
  | ["burial_place"] -> str_val (quote_escaped p.burial_place)
  | ["burial_src"] -> str_val (quote_escaped p.burial_src)
  | ["cnt"] -> eval_int_env "cnt" env
  | ["dead_dont_know_when"] -> bool_val (p.death = DeadDontKnowWhen)
  | ["death"; s] ->
      let od =
        match p.death with
        [ Death _ cd -> Some (Adef.date_of_cdate cd)
        | _ -> None ]
      in
      eval_date_var od s
  | ["death_place"] -> str_val (quote_escaped p.death_place)
  | ["death_src"] -> str_val (quote_escaped p.death_src)
  | ["died_young"] -> bool_val (p.death = DeadYoung)
  | ["digest"] -> eval_string_env "digest" env
  | ["dont_know_if_dead"] -> bool_val (p.death = DontKnowIfDead)
  | ["dr_disappeared"] -> eval_is_death_reason Disappeared p.death
  | ["dr_executed"] -> eval_is_death_reason Executed p.death
  | ["dr_killed"] -> eval_is_death_reason Killed p.death
  | ["dr_murdered"] -> eval_is_death_reason Murdered p.death
  | ["dr_unspecified"] -> eval_is_death_reason Unspecified p.death
  | ["first_name"] -> str_val (quote_escaped p.first_name)
  | ["first_name_alias"] -> eval_string_env "first_name_alias" env
  | ["has_aliases"] -> bool_val (p.aliases <> [])
  | ["has_birth_date"] -> bool_val (Adef.od_of_codate p.birth <> None)
  | ["has_first_names_aliases"] -> bool_val (p.first_names_aliases <> [])
  | ["has_qualifiers"] -> bool_val (p.qualifiers <> [])
  | ["has_relations"] -> bool_val (p.rparents <> [])
  | ["has_surnames_aliases"] -> bool_val (p.surnames_aliases <> [])
  | ["has_titles"] -> bool_val (p.titles <> [])
  | ["image"] -> str_val (quote_escaped p.image)
  | ["index"] -> str_val (string_of_int (Adef.int_of_iper p.cle_index))
  | ["is_female"] -> bool_val (p.sex = Female)
  | ["is_male"] -> bool_val (p.sex = Male)
  | ["not_dead"] -> bool_val (p.death = NotDead)
  | ["notes"] -> str_val (quote_escaped p.notes)
  | ["occ"] -> str_val (if p.occ <> 0 then string_of_int p.occ else "")
  | ["occupation"] -> str_val (quote_escaped p.occupation)
  | ["public_name"] -> str_val (quote_escaped p.public_name)
  | ["qualifier"] -> eval_string_env "qualifier" env
  | ["relation" :: sl] ->
      let r =
        match get_env "cnt" env with
        [ Vint i ->
            try Some (List.nth p.rparents (i - 1)) with [ Failure _ -> None ]
        | _ -> None ]
      in
      eval_relation_var conf base env r sl
  | ["sources"] -> str_val (quote_escaped p.psources)
  | ["surname"] -> str_val (quote_escaped p.surname)
  | ["surname_alias"] -> eval_string_env "surname_alias" env
  | ["title" :: sl] ->
      let t =
        match get_env "cnt" env with
        [ Vint i ->
            try Some (List.nth p.titles (i - 1)) with [ Failure _ -> None ]
        | _ -> None ]
      in
      eval_title_var conf base env t sl
  | ["title_date_start"; s] ->
      let od =
        match get_env "cnt" env with
        [ Vint i ->
            try
              let t = List.nth p.titles (i - 1) in
              Adef.od_of_codate t.t_date_start
            with
            [ Failure _ -> None ]
        | _ -> None ]
      in
      eval_date_var od s
  | ["title_date_end"; s] ->
      let od =
        match get_env "cnt" env with
        [ Vint i ->
            try
              let t = List.nth p.titles (i - 1) in
              Adef.od_of_codate t.t_date_end
            with
            [ Failure _ -> None ]
        | _ -> None ]
      in
      eval_date_var od s
  | [s] ->
      let v = extract_var "evar_" s in
      if v <> "" then
        match p_getenv (conf.env @ conf.henv) v with
        [ Some vv -> str_val (quote_escaped vv)
        | None -> str_val "" ]
      else
        let v = extract_var "bvar_" s in
        let v =
          if v = "" then extract_var "cvar_" s (* deprecated since 5.00 *)
          else v
        in
        if v <> "" then
          str_val (try List.assoc v conf.base_env with [ Not_found -> "" ])
        else raise Not_found
  | _ -> raise Not_found ]
and eval_date_var od s = str_val (eval_date_var_aux od s)
and eval_date_var_aux od =
  fun
  [ "calendar" ->
      match od with
      [ Some (Dgreg _ Dgregorian) -> "gregorian"
      | Some (Dgreg _ Djulian) -> "julian"
      | Some (Dgreg _ Dfrench) -> "french"
      | Some (Dgreg _ Dhebrew) -> "hebrew"
      | _ -> "" ]
  | "day" ->
      match eval_date_field od with
      [ Some d -> if d.day = 0 then "" else string_of_int d.day
      | None -> "" ]
  | "month" ->
      match eval_date_field od with
      [ Some d ->
          if d.month = 0 then ""
          else
            match od with
            [ Some (Dgreg _ Dfrench) -> short_f_month d.month
            | _ -> string_of_int d.month ]
      | None -> "" ]
  | "oryear" ->
      match od with
      [ Some (Dgreg {prec = OrYear y} _) -> string_of_int y
      | Some (Dgreg {prec = YearInt y} _) -> string_of_int y
      | _ -> "" ]
  | "prec" ->
      match od with
      [ Some (Dgreg {prec = Sure} _) -> "sure"
      | Some (Dgreg {prec = About} _) -> "about"
      | Some (Dgreg {prec = Maybe} _) -> "maybe"
      | Some (Dgreg {prec = Before} _) -> "before"
      | Some (Dgreg {prec = After} _) -> "after"
      | Some (Dgreg {prec = OrYear _} _) -> "oryear"
      | Some (Dgreg {prec = YearInt _} _) -> "yearint"
      | _ -> "" ]
  | "text" ->
      match od with
      [ Some (Dtext s) -> s
      | _ -> "" ]
  | "year" ->
      match eval_date_field od with
      [ Some d -> string_of_int d.year
      | None -> "" ]
  | x ->
      let r =
        match x with
        [ "cal_french" -> eval_is_cal Dfrench od
        | "cal_gregorian" -> eval_is_cal Dgregorian od
        | "cal_hebrew" -> eval_is_cal Dhebrew od
        | "cal_julian" -> eval_is_cal Djulian od
        | "prec_no" -> if od = None then "1" else ""
        | "prec_sure" -> eval_is_prec (fun [ Sure -> True | _ -> False ]) od
        | "prec_about" -> eval_is_prec (fun [ About -> True | _ -> False ]) od
        | "prec_maybe" -> eval_is_prec (fun [ Maybe -> True | _ -> False ]) od
        | "prec_before" ->
            eval_is_prec (fun [ Before -> True | _ -> False ]) od
        | "prec_after" ->
            eval_is_prec (fun [ After -> True | _ -> False ]) od
        | "prec_oryear" ->
            eval_is_prec (fun [ OrYear _ -> True | _ -> False ]) od
        | "prec_yearint" ->
            eval_is_prec (fun [ YearInt _ -> True | _ -> False ]) od
        | _ -> raise Not_found ]
      in
      obsolete "5.00" x (if x.[0] = 'c' then "calendar" else "prec") r ]
and eval_date_field =
  fun
  [ Some d ->
      match d with
      [ Dgreg d Dgregorian -> Some d
      | Dgreg d Djulian -> Some (Calendar.julian_of_gregorian d)
      | Dgreg d Dfrench -> Some (Calendar.french_of_gregorian d)
      | Dgreg d Dhebrew -> Some (Calendar.hebrew_of_gregorian d)
      | _ -> None ]
  | None -> None ]
and eval_title_var conf base env t =
  fun
  [ ["t_estate"] ->
      match t with
      [ Some {t_place = x} -> str_val (quote_escaped x)
      | _ -> str_val "" ]
  | ["t_ident"] ->
      match t with
      [ Some {t_ident = x} -> str_val (quote_escaped x)
      | _ -> str_val "" ]
  | ["t_main"] ->
      match t with
      [ Some {t_name = Tmain} -> bool_val True
      | _ -> bool_val False ]
  | ["t_name"] ->
      match t with
      [ Some {t_name = Tname x} -> str_val (quote_escaped x)
      | _ -> str_val "" ]
  | ["t_nth"] ->
      match t with
      [ Some {t_nth = x} -> str_val (if x = 0 then "" else string_of_int x)
      | _ -> str_val "" ]
  | _ -> raise Not_found ]
and eval_relation_var conf base env r =
  fun 
  [ ["r_father" :: sl] ->
      match r with
      [ Some {r_fath = Some x} -> eval_person_var conf base env x sl
      | _ -> str_val "" ]
  | ["r_mother" :: sl] ->
      match r with
      [ Some {r_moth = Some x} -> eval_person_var conf base env x sl
      | _ -> str_val "" ]
  | ["rt_adoption"] -> eval_is_relation_type Adoption r
  | ["rt_candidate_parent"] -> eval_is_relation_type CandidateParent r
  | ["rt_empty"] ->
      match r with
      [ Some {r_fath = None; r_moth = None} | None -> bool_val True
      | _ -> bool_val False ]
  | ["rt_foster_parent"] -> eval_is_relation_type FosterParent r
  | ["rt_godparent"] -> eval_is_relation_type GodParent r
  | ["rt_regognition"] -> eval_is_relation_type Recognition r
  | _ -> raise Not_found ]
and eval_person_var conf base env (fn, sn, oc, create, var) =
  fun
  [ ["create"] ->
      match create with
      [ Update.Create _ _ -> bool_val True
      | _ -> bool_val False ]
  | ["first_name"] -> str_val (quote_escaped fn)
  | ["link"] -> bool_val (create = Update.Link)
  | ["occ"] -> str_val (if oc = 0 then "" else string_of_int oc)
  | ["surname"] -> str_val (quote_escaped sn)
  | _ -> raise Not_found ]
and eval_is_cal cal =
  fun
  [ Some (Dgreg _ x) -> if x = cal then "1" else ""
  | _ -> "" ]
and eval_is_prec cond =
  fun
  [ Some (Dgreg {prec = x} _) -> if cond x then "1" else ""
  | _ -> "" ]
and eval_is_death_reason dr =
  fun
  [ Death dr1 _ -> bool_val (dr = dr1)
  | _ -> bool_val False ]
and eval_is_relation_type rt =
  fun
  [ Some {r_type = x} -> bool_val (x = rt)
  | _ -> bool_val False ]
and eval_int_env var env =
  match get_env var env with
  [ Vint x -> str_val (string_of_int x)
  | _ -> raise Not_found ]
and eval_string_env var env =
  match get_env var env with
  [ Vstring x -> str_val (quote_escaped x)
  | _ -> str_val "" ]
;

(* print *)

value rec print_ast conf base env p =
  fun
  [ Atext s -> Wserver.wprint "%s" s
  | Atransl upp s n -> Wserver.wprint "%s" (Templ.eval_transl conf upp s n)
  | Aexpr e -> Wserver.wprint "Aexpr"
  | Avar loc s sl ->
      Templ.print_var conf base (eval_var conf base env p loc) s sl
  | Awid_hei s -> Wserver.wprint "Awid_hei"
  | Aif e alt ale -> print_if conf base env p e alt ale
  | Aforeach v el al -> print_foreach conf base env p v el al
  | Adefine f xl al alk -> print_define conf base env p f xl al alk
  | Aapply f el -> print_apply conf base env p f el
  | AapplyWithAst _ _ -> Wserver.wprint "%%apply..%%with not impl" ]
and print_define conf base env p f xl al alk =
  List.iter (print_ast conf base [(f, Vfun xl al) :: env] p) alk
and print_apply conf base env p f el =
  match get_env f env with
  [ Vfun xl al ->
      let eval_var = eval_var conf base env p in
      let eval_apply _ _ = "not impl apply in apply" in
      let print_ast = print_ast conf base env p in
      Templ.print_apply conf f print_ast (eval_var, eval_apply) xl al el
  | _ -> Wserver.wprint " %%%s?" f ]
and print_if conf base env p e alt ale =
  let eval_var = eval_var conf base env p in
  let eval_apply _ _ = "not impl apply in if" in
  let al =
    if Templ.eval_bool_expr conf (eval_var, eval_apply) e then alt else ale
  in
  List.iter (print_ast conf base env p) al
and print_foreach conf base env p (loc, s, sl) _ al =
  match [s :: sl] with
  [ ["alias"] -> print_foreach_string conf base env p al p.aliases s
  | ["first_name_alias"] ->
      print_foreach_string conf base env p al p.first_names_aliases s
  | ["qualifier"] -> print_foreach_string conf base env p al p.qualifiers s
  | ["surname_alias"] ->
      print_foreach_string conf base env p al p.surnames_aliases s
  | ["relation"] -> print_foreach_relation conf base env p al p.rparents
  | ["title"] -> print_foreach_title conf base env p al p.titles
  | _ ->
      do {
        Wserver.wprint ">%%foreach;%s" s;
        List.iter (fun s -> Wserver.wprint ".%s" s) sl;
        Wserver.wprint "?";
       } ]
and print_foreach_string conf base env p al list lab =
  let _ =
    List.fold_left
      (fun cnt nn ->
         let env = [(lab, Vstring nn) :: env] in
         let env = [("cnt", Vint cnt) :: env] in
         do { List.iter (print_ast conf base env p) al; cnt + 1 })
      0 list
  in
  ()
and print_foreach_relation conf base env p al list =
  let _ =
    List.fold_left
      (fun cnt nn ->
         let env = [("cnt", Vint cnt) :: env] in
         do { List.iter (print_ast conf base env p) al; cnt + 1 })
      1 list
  in
  ()
and print_foreach_title conf base env p al list =
  let _ =
    List.fold_left
      (fun cnt nn ->
         let env = [("cnt", Vint cnt) :: env] in
         do { List.iter (print_ast conf base env p) al; cnt + 1 })
      1 list
  in
  ()
;

value interp_templ conf base p digest astl =
  let env = [("digest", Vstring digest)] in
  List.iter (print_ast conf base env p) astl
;

value print_update_ind conf base p digest =
  match p_getenv conf.env "m" with
  [ Some ("MRG_IND_OK" | "MRG_MOD_IND_OK") | Some ("MOD_IND" | "MOD_IND_OK") |
    Some ("ADD_IND" | "ADD_IND_OK") ->
      let astl = Templ.input conf "updind" in
      do { html1 conf; interp_templ conf base p digest astl }
  | _ -> incorrect_request conf ]
;

value print_del1 conf base p =
  let title _ =
    let s = transl_nth conf "person/persons" 0 in
    Wserver.wprint "%s" (capitale (transl_decline conf "delete" s))
  in
  do {
    header conf title;
    tag "form" "method=\"post\" action=\"%s\"" conf.command begin
      tag "p" begin
        Util.hidden_env conf;
        xtag "input" "type=\"hidden\" name=\"m\" value=\"DEL_IND_OK\"";
        xtag "input" "type=\"hidden\" name=\"i\" value=\"%d\""
          (Adef.int_of_iper p.cle_index);
        xtag "input" "type=\"submit\" value=\"Ok\"";
      end;
    end;
    trailer conf;
  }
;

value print_add conf base =
  let p =
    {first_name = ""; surname = ""; occ = 0; image = "";
     first_names_aliases = []; surnames_aliases = []; public_name = "";
     qualifiers = []; aliases = []; titles = []; rparents = []; related = [];
     occupation = ""; sex = Neuter; access = IfTitles;
     birth = Adef.codate_None; birth_place = ""; birth_src = "";
     baptism = Adef.codate_None; baptism_place = ""; baptism_src = "";
     death = DontKnowIfDead; death_place = ""; death_src = "";
     burial = UnknownBurial; burial_place = ""; burial_src = ""; notes = "";
     psources = ""; cle_index = bogus_person_index}
  in
  print_update_ind conf base p ""
;

value print_mod conf base =
  match p_getint conf.env "i" with
  [ Some i ->
      let p = base.data.persons.get i in
      let digest = Update.digest_person p in
      print_update_ind conf base (string_person_of base p) digest
  | _ -> incorrect_request conf ]
;

value print_del conf base =
  match p_getint conf.env "i" with
  [ Some i ->
      let p = base.data.persons.get i in
      print_del1 conf base (string_person_of base p)
  | _ -> incorrect_request conf ]
;
