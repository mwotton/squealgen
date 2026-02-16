-- Regression test for FK referenced-column ordering bug.
--
-- The child_composite FK intentionally has column order MISMATCH between
-- local columns (local_b, local_a) and referenced columns (ref_b, ref_a).
-- This tests that squealgen correctly uses confkey (referenced) not conkey
-- (local) when extracting FK target column order. A buggy implementation
-- would emit ['local_b','local_a'] as target columns instead of ['ref_b','ref_a'].

CREATE SCHEMA ref;

CREATE TABLE public.parent_single (
  id integer PRIMARY KEY
);

CREATE TABLE public.child_single (
  local_parent_id integer NOT NULL,
  CONSTRAINT child_single_parent_fk FOREIGN KEY (local_parent_id)
    REFERENCES public.parent_single (id)
);

CREATE TABLE public.parent_composite (
  ref_a integer,
  ref_b integer,
  PRIMARY KEY (ref_a, ref_b)
);

CREATE TABLE public.child_composite (
  local_b integer NOT NULL,
  local_a integer NOT NULL,
  CONSTRAINT child_composite_parent_fk FOREIGN KEY (local_b, local_a)
    REFERENCES public.parent_composite (ref_b, ref_a)
);

CREATE TABLE ref.parent_cross (
  target_left integer,
  target_right integer,
  PRIMARY KEY (target_left, target_right)
);

CREATE TABLE public.child_cross (
  left_local integer NOT NULL,
  right_local integer NOT NULL,
  CONSTRAINT child_cross_parent_fk FOREIGN KEY (left_local, right_local)
    REFERENCES ref.parent_cross (target_left, target_right)
);

CREATE TABLE public.self_ref (
  id integer PRIMARY KEY,
  parent_local integer,
  CONSTRAINT self_ref_parent_fk FOREIGN KEY (parent_local)
    REFERENCES public.self_ref (id)
);
