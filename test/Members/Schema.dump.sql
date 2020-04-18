--
-- PostgreSQL database dump
--

-- Dumped from database version 11.7 (Ubuntu 11.7-0ubuntu0.19.10.1)
-- Dumped by pg_dump version 11.7 (Ubuntu 11.7-0ubuntu0.19.10.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: agroup; Type: TABLE; Schema: public; Owner: mark
--

CREATE TABLE public.agroup (
    id integer NOT NULL,
    name text NOT NULL,
    fake_true boolean DEFAULT true NOT NULL,
    leader integer NOT NULL,
    CONSTRAINT agroup_fake_true_check CHECK (fake_true)
);


ALTER TABLE public.agroup OWNER TO mark;

--
-- Name: agroup_id_seq; Type: SEQUENCE; Schema: public; Owner: mark
--

CREATE SEQUENCE public.agroup_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.agroup_id_seq OWNER TO mark;

--
-- Name: agroup_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mark
--

ALTER SEQUENCE public.agroup_id_seq OWNED BY public.agroup.id;


--
-- Name: group_member; Type: TABLE; Schema: public; Owner: mark
--

CREATE TABLE public.group_member (
    id integer NOT NULL,
    group_id integer NOT NULL,
    is_leader boolean
);


ALTER TABLE public.group_member OWNER TO mark;

--
-- Name: group_member_id_seq; Type: SEQUENCE; Schema: public; Owner: mark
--

CREATE SEQUENCE public.group_member_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.group_member_id_seq OWNER TO mark;

--
-- Name: group_member_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mark
--

ALTER SEQUENCE public.group_member_id_seq OWNED BY public.group_member.id;


--
-- Name: groupies; Type: VIEW; Schema: public; Owner: mark
--

CREATE VIEW public.groupies AS
SELECT
    NULL::integer AS id,
    NULL::text AS name,
    NULL::boolean AS fake_true,
    NULL::integer AS leader,
    NULL::json AS json_agg;


ALTER TABLE public.groupies OWNER TO mark;

--
-- Name: agroup id; Type: DEFAULT; Schema: public; Owner: mark
--

ALTER TABLE ONLY public.agroup ALTER COLUMN id SET DEFAULT nextval('public.agroup_id_seq'::regclass);


--
-- Name: group_member id; Type: DEFAULT; Schema: public; Owner: mark
--

ALTER TABLE ONLY public.group_member ALTER COLUMN id SET DEFAULT nextval('public.group_member_id_seq'::regclass);


--
-- Data for Name: agroup; Type: TABLE DATA; Schema: public; Owner: mark
--

COPY public.agroup (id, name, fake_true, leader) FROM stdin;
\.


--
-- Data for Name: group_member; Type: TABLE DATA; Schema: public; Owner: mark
--

COPY public.group_member (id, group_id, is_leader) FROM stdin;
\.


--
-- Name: agroup_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mark
--

SELECT pg_catalog.setval('public.agroup_id_seq', 3, true);


--
-- Name: group_member_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mark
--

SELECT pg_catalog.setval('public.group_member_id_seq', 1, false);


--
-- Name: agroup agroup_pkey; Type: CONSTRAINT; Schema: public; Owner: mark
--

ALTER TABLE ONLY public.agroup
    ADD CONSTRAINT agroup_pkey PRIMARY KEY (id);


--
-- Name: group_member group_member_pkey; Type: CONSTRAINT; Schema: public; Owner: mark
--

ALTER TABLE ONLY public.group_member
    ADD CONSTRAINT group_member_pkey PRIMARY KEY (id);


--
-- Name: leader_uniqueness; Type: INDEX; Schema: public; Owner: mark
--

CREATE UNIQUE INDEX leader_uniqueness ON public.agroup USING btree (id, fake_true);


--
-- Name: one_leader; Type: INDEX; Schema: public; Owner: mark
--

CREATE UNIQUE INDEX one_leader ON public.group_member USING btree (group_id) WHERE is_leader;


--
-- Name: groupies _RETURN; Type: RULE; Schema: public; Owner: mark
--

CREATE OR REPLACE VIEW public.groupies AS
 SELECT agroup.id,
    agroup.name,
    agroup.fake_true,
    agroup.leader,
    json_agg(ROW(group_member.id, group_member.group_id, group_member.is_leader)) AS json_agg
   FROM (public.agroup
     JOIN public.group_member ON ((group_member.group_id = agroup.id)))
  GROUP BY agroup.id;


--
-- Name: agroup agroup_leader_fkey; Type: FK CONSTRAINT; Schema: public; Owner: mark
--

ALTER TABLE ONLY public.agroup
    ADD CONSTRAINT agroup_leader_fkey FOREIGN KEY (leader) REFERENCES public.group_member(id);


--
-- Name: group_member group_member_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: mark
--

ALTER TABLE ONLY public.group_member
    ADD CONSTRAINT group_member_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.agroup(id);


--
-- Name: group_member group_member_group_id_fkey1; Type: FK CONSTRAINT; Schema: public; Owner: mark
--

ALTER TABLE ONLY public.group_member
    ADD CONSTRAINT group_member_group_id_fkey1 FOREIGN KEY (group_id, is_leader) REFERENCES public.agroup(id, fake_true);


--
-- PostgreSQL database dump complete
--

