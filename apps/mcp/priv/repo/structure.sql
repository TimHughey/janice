--
-- PostgreSQL database dump
--

-- Dumped from database version 9.5.5
-- Dumped by pg_dump version 9.5.5

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: dutycycles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE dutycycles (
    id integer NOT NULL,
    name character varying(25) NOT NULL,
    description character varying(100),
    enable boolean DEFAULT false,
    device_sw character varying(25) NOT NULL,
    device_state boolean DEFAULT false NOT NULL,
    run_ms integer DEFAULT 600000,
    idle_ms integer DEFAULT 600000,
    state_at timestamp without time zone,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: dutycycles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE dutycycles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dutycycles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE dutycycles_id_seq OWNED BY dutycycles.id;


--
-- Name: mixtanks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE mixtanks (
    id integer NOT NULL,
    name character varying(25) NOT NULL,
    description text,
    enable boolean NOT NULL,
    sensor character varying(25) NOT NULL,
    ref_sensor character varying(25) NOT NULL,
    heat_sw character varying(25) NOT NULL,
    heat_state boolean DEFAULT false NOT NULL,
    air_sw character varying(25) NOT NULL,
    air_state boolean DEFAULT false NOT NULL,
    air_run_ms integer DEFAULT 0 NOT NULL,
    air_idle_ms integer DEFAULT 0 NOT NULL,
    pump_sw character varying(25) NOT NULL,
    pump_state boolean DEFAULT false NOT NULL,
    pump_run_ms integer DEFAULT 0 NOT NULL,
    pump_idle_ms integer DEFAULT 0 NOT NULL,
    state_at timestamp without time zone DEFAULT timezone('utc'::text, now()),
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: mixtanks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE mixtanks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mixtanks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE mixtanks_id_seq OWNED BY mixtanks.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp without time zone
);


--
-- Name: sensors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE sensors (
    id integer NOT NULL,
    name character varying(25) NOT NULL,
    provider character varying(10) DEFAULT 'owfs'::character varying NOT NULL,
    reading character varying(25) NOT NULL,
    description text,
    value double precision DEFAULT 0.0 NOT NULL,
    read_at timestamp without time zone DEFAULT timezone('utc'::text, now()),
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: sensors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE sensors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sensors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE sensors_id_seq OWNED BY sensors.id;


--
-- Name: switches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE switches (
    id integer NOT NULL,
    name character varying(25) NOT NULL,
    provider character varying(25) DEFAULT 'owfs'::character varying NOT NULL,
    description text,
    "group" character varying(25) NOT NULL,
    pio character varying(6) NOT NULL,
    "position" boolean,
    position_at timestamp without time zone DEFAULT timezone('utc'::text, now()),
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: switches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE switches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: switches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE switches_id_seq OWNED BY switches.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY dutycycles ALTER COLUMN id SET DEFAULT nextval('dutycycles_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY mixtanks ALTER COLUMN id SET DEFAULT nextval('mixtanks_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY sensors ALTER COLUMN id SET DEFAULT nextval('sensors_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY switches ALTER COLUMN id SET DEFAULT nextval('switches_id_seq'::regclass);


--
-- Name: dutycycles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY dutycycles
    ADD CONSTRAINT dutycycles_pkey PRIMARY KEY (id);


--
-- Name: mixtanks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY mixtanks
    ADD CONSTRAINT mixtanks_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sensors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY sensors
    ADD CONSTRAINT sensors_pkey PRIMARY KEY (id);


--
-- Name: switches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY switches
    ADD CONSTRAINT switches_pkey PRIMARY KEY (id);


--
-- Name: dutycycles_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX dutycycles_name_index ON dutycycles USING btree (name);


--
-- Name: mixtanks_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX mixtanks_name_index ON mixtanks USING btree (name);


--
-- Name: sensors_name_reading_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX sensors_name_reading_index ON sensors USING btree (name, reading);


--
-- Name: switches_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX switches_name_index ON switches USING btree (name);


--
-- PostgreSQL database dump complete
--

INSERT INTO "schema_migrations" (version) VALUES (20160228130821), (20160314211624), (20160318201342), (20160319202216), (20160325040124), (20160325042247);

