(* Copyright (C) 1999-2004 Henry Cejtin, Matthew Fluet, Suresh
 *    Jagannathan, and Stephen Weeks.
 * Copyright (C) 1997-1999 NEC Research Institute.
 *
 * MLton is released under the GNU General Public License (GPL).
 * Please see the file MLton-LICENSE for license information.
 *)
type int = Int.t

signature SSA_TREE2_STRUCTS = 
   sig
      include ATOMS
   end

signature SSA_TREE2 = 
   sig
      include SSA_TREE2_STRUCTS

      structure Type:
	 sig
	    type t
	       
	    datatype dest =
	       Array of t
	     | Datatype of Tycon.t
	     | IntInf
	     | Object of {args: {elt: t, isMutable: bool} vector,
			  con: Con.t option}
	     | Real of RealSize.t
	     | Thread
	     | Vector of t
	     | Weak of t
	     | Word of WordSize.t

	    val array: t -> t
	    val bool: t
	    val conApp: Con.t * {elt: t, isMutable: bool} vector -> t
	    val checkPrimApp: {args: t vector,
			       prim: t Prim.t,
			       result: t,
			       targs: t vector} -> bool
	    val datatypee: Tycon.t -> t
	    val dest: t -> dest
	    val equals: t * t -> bool
	    val intInf: t
	    val join: t * t -> t
	    val layout: t -> Layout.t
	    val object: {args: {elt: t, isMutable: bool} vector,
			 con: Con.t option} -> t
	    val ofConst: Const.t -> t
	    val plist: t -> PropertyList.t
	    val real: RealSize.t -> t
	    val reff: t -> t
	    val thread: t
	    val tuple: {elt: t, isMutable: bool} vector -> t
	    val vector: t -> t
	    val weak: t -> t
	    val word: WordSize.t -> t
	    val unit: t
	 end

      structure Exp:
	 sig
	    datatype t =
	       Const of Const.t
	     | Inject of {sum: Tycon.t,
			  variant: Var.t}
	     | Object of {args: Var.t vector,
			  con: Con.t option}
	     | PrimApp of {args: Var.t vector,
			   prim: Type.t Prim.t,
			   targs: Type.t vector}
	     | Profile of ProfileExp.t
	     | Select of {object: Var.t,
			  offset: int}
	     | Update of {object: Var.t,
			  offset: int,
			  value: Var.t}
	     | Var of Var.t

	    val equals: t * t -> bool
	    val foreachVar: t * (Var.t -> unit) -> unit
	    val isProfile: t -> bool
	    val hash: t -> Word.t
	    val layout: t -> Layout.t
	    val maySideEffect: t -> bool
	    val replaceVar: t * (Var.t -> Var.t) -> t
	    val toString: t -> string
	    val unit: t
	 end

      structure Statement:
	 sig
	    datatype t = T of {exp: Exp.t,
			       ty: Type.t,
			       var: Var.t option}

	    val clear: t -> unit (* clear the var *)
	    val equals: t * t -> bool
	    val exp: t -> Exp.t
	    val layout: t -> Layout.t
	    val prettifyGlobals: t vector -> (Var.t -> string option)
	    val profile: ProfileExp.t -> t
	    val var: t -> Var.t option
	 end
      
      structure Cases:
	 sig
	    datatype t =
	       Con of (Con.t * Label.t) vector
	     | Word of WordSize.t * (WordX.t * Label.t) vector

	    val forall: t * (Label.t -> bool) -> bool
	    val foreach: t * (Label.t -> unit) -> unit
	    val hd: t -> Label.t
	    val isEmpty: t -> bool
	    val length: t -> int
	    val map: t * (Label.t -> Label.t) -> t
	 end

      structure Handler: HANDLER
      sharing Handler.Label = Label

      structure Return: RETURN
      sharing Return.Handler = Handler

      structure Transfer:
	 sig
	    datatype t =
	       Arith of {args: Var.t vector,
			 overflow: Label.t, (* Must be nullary. *)
			 prim: Type.t Prim.t,
			 success: Label.t, (* Must be unary. *)
			 ty: Type.t} (* int or word *)
	     | Bug  (* MLton thought control couldn't reach here. *)
	     | Call of {args: Var.t vector,
			func: Func.t,
			return: Return.t}
	     | Case of {cases: Cases.t,
			default: Label.t option, (* Must be nullary. *)
			test: Var.t}
	     | Goto of {args: Var.t vector,
			dst: Label.t}
	     (* Raise implicitly raises to the caller.  
	      * I.E. the local handler stack must be empty.
	      *)
	     | Raise of Var.t vector
	     | Return of Var.t vector
	     | Runtime of {args: Var.t vector,
			   prim: Type.t Prim.t,
			   return: Label.t} (* Must be nullary. *)

	    val equals: t * t -> bool
	    val foreachFunc : t * (Func.t -> unit) -> unit
	    val foreachLabel: t * (Label.t -> unit) -> unit
	    val foreachLabelVar: t * (Label.t -> unit) * (Var.t -> unit) -> unit
	    val foreachVar: t * (Var.t -> unit) -> unit
	    val hash: t -> Word.t 
	    val iff: Var.t * {falsee: Label.t, truee: Label.t} -> t
	    val layout: t -> Layout.t
	    val replaceLabelVar: t * (Label.t -> Label.t) * (Var.t -> Var.t) -> t
	    val replaceLabel: t * (Label.t -> Label.t) -> t
	    val replaceVar: t * (Var.t -> Var.t) -> t
	 end

      structure Block:
	 sig
	    datatype t =
	       T of {args: (Var.t * Type.t) vector,
		     label: Label.t,
		     statements: Statement.t vector,
		     transfer: Transfer.t}

	    val args: t -> (Var.t * Type.t) vector
	    val clear: t -> unit
	    val label: t -> Label.t
	    val layout: t -> Layout.t
	    val statements: t -> Statement.t vector
	    val transfer: t -> Transfer.t
	 end

      structure Datatype:
	 sig
	    datatype t =
	       T of {cons: {args: {elt: Type.t,
				   isMutable: bool} vector,
			    con: Con.t} vector,
		     tycon: Tycon.t}

	    val layout: t -> Layout.t
	 end

      structure Function:
	 sig
	    type t

	    val alphaRename: t -> t
	    val blocks: t -> Block.t vector
	    (* clear the plists for all bound variables and labels that appear
	     * in the function, but not the function name's plist.
	     *)
	    val clear: t -> unit
	    val controlFlow:
	       t -> {graph: unit DirectedGraph.t,
		     labelNode: Label.t -> unit DirectedGraph.Node.t,
		     nodeBlock: unit DirectedGraph.Node.t -> Block.t}
	    val dest: t -> {args: (Var.t * Type.t) vector,
			    blocks: Block.t vector,
			    mayInline: bool,
			    name: Func.t,
			    raises: Type.t vector option,
			    returns: Type.t vector option,
			    start: Label.t}
	    (* dfs (f, v) visits the blocks in depth-first order, applying v b
	     * for block b to yield v', then visiting b's descendents,
	     * then applying v' ().
	     *)
	    val dfs: t * (Block.t -> unit -> unit) -> unit
	    val dominatorTree: t -> Block.t Tree.t
	    val foreachVar: t * (Var.t * Type.t -> unit) -> unit
	    val layout: t -> Layout.t
	    val layoutDot:
	       t * (Var.t -> string option) -> {graph: Layout.t,
						tree: unit -> Layout.t}
	    val name: t -> Func.t
	    val new: {args: (Var.t * Type.t) vector,
		      blocks: Block.t vector,
		      mayInline: bool,
		      name: Func.t,
		      raises: Type.t vector option,
		      returns: Type.t vector option,
		      start: Label.t} -> t
	    val profile: t * SourceInfo.t -> t
	    val start: t -> Label.t
	 end
     
      structure Program:
	 sig
	    datatype t =
	       T of {datatypes: Datatype.t vector,
		     functions: Function.t list,
		     globals: Statement.t vector,
		     main: Func.t (* Must be nullary. *)}

	    val clear: t -> unit
	    val clearTop: t -> unit
	    val foreachPrim: t * (Type.t Prim.t -> unit) -> unit
	    val foreachVar: t * (Var.t * Type.t -> unit) -> unit
	    val hasPrim: t * (Type.t Prim.t -> bool) -> bool
	    val layouts: t * (Layout.t -> unit) -> unit
	    val layoutStats: t -> Layout.t
	    val profile: t -> t
	 end
   end