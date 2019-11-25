--
-- PostgreSQL database dump
--

-- Dumped from database version 11.4
-- Dumped by pg_dump version 11.4

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
-- Name: dutycycle; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dutycycle (
    id bigint NOT NULL,
    name character varying(50) NOT NULL,
    comment text,
    enable boolean DEFAULT false NOT NULL,
    device character varying(25) NOT NULL,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    log boolean DEFAULT false,
    standalone boolean DEFAULT false
);


--
-- Name: dutycycle_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dutycycle_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dutycycle_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dutycycle_id_seq OWNED BY public.dutycycle.id;


--
-- Name: dutycycle_profile; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dutycycle_profile (
    id bigint NOT NULL,
    dutycycle_id bigint,
    name character varying(25) NOT NULL,
    active boolean DEFAULT false NOT NULL,
    run_ms integer DEFAULT 600000 NOT NULL,
    idle_ms integer DEFAULT 600000 NOT NULL,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: dutycycle_profile_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dutycycle_profile_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dutycycle_profile_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dutycycle_profile_id_seq OWNED BY public.dutycycle_profile.id;


--
-- Name: dutycycle_state; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dutycycle_state (
    id bigint NOT NULL,
    dutycycle_id bigint,
    state character varying(15) DEFAULT 'stopped'::character varying NOT NULL,
    dev_state boolean DEFAULT false NOT NULL,
    run_at timestamp without time zone,
    run_end_at timestamp without time zone,
    idle_at timestamp without time zone,
    idle_end_at timestamp without time zone,
    started_at timestamp without time zone,
    state_at timestamp without time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: dutycycle_state_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dutycycle_state_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dutycycle_state_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dutycycle_state_id_seq OWNED BY public.dutycycle_state.id;


--
-- Name: message; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.message (
    id bigint NOT NULL,
    direction character varying(15) NOT NULL,
    payload text,
    dropped boolean DEFAULT false NOT NULL,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: message_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.message_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: message_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.message_id_seq OWNED BY public.message.id;


--
-- Name: remote; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.remote (
    id bigint NOT NULL,
    host character varying(20) NOT NULL,
    name character varying(35) NOT NULL,
    hw character varying(10) NOT NULL,
    firmware_vsn character varying(32) DEFAULT '0000000'::character varying NOT NULL,
    last_start_at timestamp without time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    last_seen_at timestamp without time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    preferred_vsn character varying(255) DEFAULT 'stable'::character varying,
    batt_mv integer DEFAULT 0,
    reset_reason character varying(25) DEFAULT 'unknown'::character varying,
    ap_rssi integer DEFAULT 0,
    ap_pri_chan integer DEFAULT 0,
    ap_sec_chan integer DEFAULT 0,
    heap_free integer DEFAULT 0,
    heap_min integer DEFAULT 0,
    uptime_us bigint DEFAULT 0,
    project_name character varying(32),
    idf_vsn character varying(32),
    app_elf_sha256 character varying(255),
    build_date character varying(16),
    build_time character varying(16),
    magic_word character varying(255),
    secure_vsn integer,
    bssid character varying(255) DEFAULT 'xx:xx:xx:xx:xx:xx'::character varying,
    metric_freq_secs integer DEFAULT 60,
    metric_at timestamp(0) without time zone DEFAULT NULL::timestamp without time zone
);


--
-- Name: remote_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.remote_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: remote_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.remote_id_seq OWNED BY public.remote.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp without time zone
);


--
-- Name: sensor; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sensor (
    id bigint NOT NULL,
    name character varying(40) NOT NULL,
    description text DEFAULT 'new sensor'::text,
    device character varying(40) NOT NULL,
    type character varying(10) DEFAULT 'undef'::character varying NOT NULL,
    dev_latency bigint,
    reading_at timestamp without time zone DEFAULT (timezone('utc'::text, now()) - '03:00:00'::interval),
    last_seen_at timestamp without time zone DEFAULT timezone('utc'::text, now()),
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    metric_freq_secs integer DEFAULT 60,
    metric_at timestamp(0) without time zone DEFAULT NULL::timestamp without time zone
);


--
-- Name: sensor_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sensor_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sensor_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sensor_id_seq OWNED BY public.sensor.id;


--
-- Name: sensor_relhum; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sensor_relhum (
    id bigint NOT NULL,
    sensor_id bigint,
    rh double precision,
    ttl_ms integer DEFAULT 10000 NOT NULL,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: sensor_relhum_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sensor_relhum_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sensor_relhum_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sensor_relhum_id_seq OWNED BY public.sensor_relhum.id;


--
-- Name: sensor_soil; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sensor_soil (
    id bigint NOT NULL,
    sensor_id bigint,
    moisture double precision,
    ttl_ms integer DEFAULT 10000 NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: sensor_soil_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sensor_soil_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sensor_soil_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sensor_soil_id_seq OWNED BY public.sensor_soil.id;


--
-- Name: sensor_temperature; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sensor_temperature (
    id bigint NOT NULL,
    sensor_id bigint,
    tc double precision,
    tf double precision,
    ttl_ms integer DEFAULT 10000 NOT NULL,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: sensor_temperature_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sensor_temperature_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sensor_temperature_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sensor_temperature_id_seq OWNED BY public.sensor_temperature.id;


--
-- Name: switch; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.switch (
    id bigint NOT NULL,
    device character varying(40) NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    dev_latency bigint DEFAULT 0 NOT NULL,
    discovered_at timestamp without time zone DEFAULT timezone('utc'::text, now()),
    last_cmd_at timestamp without time zone DEFAULT (timezone('utc'::text, now()) - '03:00:00'::interval),
    last_seen_at timestamp without time zone DEFAULT timezone('utc'::text, now()),
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: switch_cmd; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.switch_cmd (
    id bigint NOT NULL,
    refid character varying(40) NOT NULL,
    switch_id bigint,
    name character varying(40),
    acked boolean DEFAULT false NOT NULL,
    rt_latency bigint DEFAULT 0 NOT NULL,
    sent_at timestamp without time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    ack_at timestamp without time zone,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    orphan boolean DEFAULT false
);


--
-- Name: switch_cmd_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.switch_cmd_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: switch_cmd_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.switch_cmd_id_seq OWNED BY public.switch_cmd.id;


--
-- Name: switch_group; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.switch_group (
    id bigint NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(100),
    members character varying(2048)[],
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: switch_group_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.switch_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: switch_group_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.switch_group_id_seq OWNED BY public.switch_group.id;


--
-- Name: switch_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.switch_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: switch_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.switch_id_seq OWNED BY public.switch.id;


--
-- Name: switch_state; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.switch_state (
    id bigint NOT NULL,
    switch_id bigint,
    name character varying(40) NOT NULL,
    description text DEFAULT 'new switch'::text,
    pio integer DEFAULT 0 NOT NULL,
    state boolean DEFAULT false NOT NULL,
    ttl_ms integer DEFAULT 1000 NOT NULL,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: switch_state_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.switch_state_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: switch_state_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.switch_state_id_seq OWNED BY public.switch_state.id;


--
-- Name: thermostat; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.thermostat (
    id bigint NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(100),
    owned_by character varying(50),
    enable boolean DEFAULT false NOT NULL,
    switch character varying(50) NOT NULL,
    active_profile character varying(25),
    sensor character varying(40) NOT NULL,
    state character varying(15) DEFAULT 'new'::character varying NOT NULL,
    state_at timestamp without time zone,
    log_activity boolean DEFAULT false NOT NULL,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: thermostat_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.thermostat_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: thermostat_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.thermostat_id_seq OWNED BY public.thermostat.id;


--
-- Name: thermostat_profile; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.thermostat_profile (
    id bigint NOT NULL,
    thermostat_id bigint,
    name character varying(25) NOT NULL,
    low_offset double precision DEFAULT 0.0 NOT NULL,
    high_offset double precision DEFAULT 0.0 NOT NULL,
    check_ms integer DEFAULT 60000 NOT NULL,
    ref_sensor character varying(40),
    ref_offset double precision,
    fixed_setpt double precision,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: thermostat_profile_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.thermostat_profile_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: thermostat_profile_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.thermostat_profile_id_seq OWNED BY public.thermostat_profile.id;


--
-- Name: dutycycle id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dutycycle ALTER COLUMN id SET DEFAULT nextval('public.dutycycle_id_seq'::regclass);


--
-- Name: dutycycle_profile id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dutycycle_profile ALTER COLUMN id SET DEFAULT nextval('public.dutycycle_profile_id_seq'::regclass);


--
-- Name: dutycycle_state id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dutycycle_state ALTER COLUMN id SET DEFAULT nextval('public.dutycycle_state_id_seq'::regclass);


--
-- Name: message id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message ALTER COLUMN id SET DEFAULT nextval('public.message_id_seq'::regclass);


--
-- Name: remote id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.remote ALTER COLUMN id SET DEFAULT nextval('public.remote_id_seq'::regclass);


--
-- Name: sensor id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sensor ALTER COLUMN id SET DEFAULT nextval('public.sensor_id_seq'::regclass);


--
-- Name: sensor_relhum id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sensor_relhum ALTER COLUMN id SET DEFAULT nextval('public.sensor_relhum_id_seq'::regclass);


--
-- Name: sensor_soil id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sensor_soil ALTER COLUMN id SET DEFAULT nextval('public.sensor_soil_id_seq'::regclass);


--
-- Name: sensor_temperature id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sensor_temperature ALTER COLUMN id SET DEFAULT nextval('public.sensor_temperature_id_seq'::regclass);


--
-- Name: switch id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.switch ALTER COLUMN id SET DEFAULT nextval('public.switch_id_seq'::regclass);


--
-- Name: switch_cmd id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.switch_cmd ALTER COLUMN id SET DEFAULT nextval('public.switch_cmd_id_seq'::regclass);


--
-- Name: switch_group id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.switch_group ALTER COLUMN id SET DEFAULT nextval('public.switch_group_id_seq'::regclass);


--
-- Name: switch_state id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.switch_state ALTER COLUMN id SET DEFAULT nextval('public.switch_state_id_seq'::regclass);


--
-- Name: thermostat id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thermostat ALTER COLUMN id SET DEFAULT nextval('public.thermostat_id_seq'::regclass);


--
-- Name: thermostat_profile id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thermostat_profile ALTER COLUMN id SET DEFAULT nextval('public.thermostat_profile_id_seq'::regclass);


--
-- Name: dutycycle dutycycle_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dutycycle
    ADD CONSTRAINT dutycycle_pkey PRIMARY KEY (id);


--
-- Name: dutycycle_profile dutycycle_profile_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dutycycle_profile
    ADD CONSTRAINT dutycycle_profile_pkey PRIMARY KEY (id);


--
-- Name: dutycycle_state dutycycle_state_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dutycycle_state
    ADD CONSTRAINT dutycycle_state_pkey PRIMARY KEY (id);


--
-- Name: message message_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message
    ADD CONSTRAINT message_pkey PRIMARY KEY (id);


--
-- Name: remote remote_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.remote
    ADD CONSTRAINT remote_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sensor sensor_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sensor
    ADD CONSTRAINT sensor_pkey PRIMARY KEY (id);


--
-- Name: sensor_relhum sensor_relhum_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sensor_relhum
    ADD CONSTRAINT sensor_relhum_pkey PRIMARY KEY (id);


--
-- Name: sensor_soil sensor_soil_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sensor_soil
    ADD CONSTRAINT sensor_soil_pkey PRIMARY KEY (id);


--
-- Name: sensor_temperature sensor_temperature_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sensor_temperature
    ADD CONSTRAINT sensor_temperature_pkey PRIMARY KEY (id);


--
-- Name: switch_cmd switch_cmd_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.switch_cmd
    ADD CONSTRAINT switch_cmd_pkey PRIMARY KEY (id);


--
-- Name: switch_group switch_group_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.switch_group
    ADD CONSTRAINT switch_group_pkey PRIMARY KEY (id);


--
-- Name: switch switch_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.switch
    ADD CONSTRAINT switch_pkey PRIMARY KEY (id);


--
-- Name: switch_state switch_state_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.switch_state
    ADD CONSTRAINT switch_state_pkey PRIMARY KEY (id);


--
-- Name: thermostat thermostat_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thermostat
    ADD CONSTRAINT thermostat_pkey PRIMARY KEY (id);


--
-- Name: thermostat_profile thermostat_profile_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thermostat_profile
    ADD CONSTRAINT thermostat_profile_pkey PRIMARY KEY (id);


--
-- Name: dutycycle_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX dutycycle_name_index ON public.dutycycle USING btree (name);


--
-- Name: dutycycle_profile_name_dutycycle_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX dutycycle_profile_name_dutycycle_id_index ON public.dutycycle_profile USING btree (name, dutycycle_id);


--
-- Name: dutycycle_state_dutycycle_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX dutycycle_state_dutycycle_id_index ON public.dutycycle_state USING btree (dutycycle_id);


--
-- Name: message_inserted_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX message_inserted_at_index ON public.message USING btree (inserted_at);


--
-- Name: remote_host_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX remote_host_index ON public.remote USING btree (host);


--
-- Name: remote_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX remote_name_index ON public.remote USING btree (name);


--
-- Name: sensor_device_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX sensor_device_index ON public.sensor USING btree (device);


--
-- Name: sensor_last_seen_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sensor_last_seen_at_index ON public.sensor USING btree (last_seen_at);


--
-- Name: sensor_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX sensor_name_index ON public.sensor USING btree (name);


--
-- Name: sensor_reading_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sensor_reading_at_index ON public.sensor USING btree (reading_at);


--
-- Name: sensor_relhum_inserted_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sensor_relhum_inserted_at_index ON public.sensor_relhum USING btree (inserted_at);


--
-- Name: sensor_relhum_sensor_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sensor_relhum_sensor_id_index ON public.sensor_relhum USING btree (sensor_id);


--
-- Name: sensor_soil_sensor_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sensor_soil_sensor_id_index ON public.sensor_soil USING btree (sensor_id);


--
-- Name: sensor_temperature_inserted_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sensor_temperature_inserted_at_index ON public.sensor_temperature USING btree (inserted_at);


--
-- Name: sensor_temperature_sensor_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sensor_temperature_sensor_id_index ON public.sensor_temperature USING btree (sensor_id);


--
-- Name: switch_cmd_ack_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX switch_cmd_ack_at_index ON public.switch_cmd USING btree (ack_at);


--
-- Name: switch_cmd_refid_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX switch_cmd_refid_index ON public.switch_cmd USING btree (refid);


--
-- Name: switch_cmd_sent_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX switch_cmd_sent_at_index ON public.switch_cmd USING btree (sent_at);


--
-- Name: switch_cmd_switch_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX switch_cmd_switch_id_index ON public.switch_cmd USING btree (switch_id);


--
-- Name: switch_device_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX switch_device_index ON public.switch USING btree (device);


--
-- Name: switch_discovered_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX switch_discovered_at_index ON public.switch USING btree (discovered_at);


--
-- Name: switch_group_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX switch_group_name_index ON public.switch_group USING btree (name);


--
-- Name: switch_last_seen_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX switch_last_seen_at_index ON public.switch USING btree (last_seen_at);


--
-- Name: switch_state_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX switch_state_name_index ON public.switch_state USING btree (name);


--
-- Name: switch_state_switch_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX switch_state_switch_id_index ON public.switch_state USING btree (switch_id);


--
-- Name: switch_state_switch_id_pio_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX switch_state_switch_id_pio_index ON public.switch_state USING btree (switch_id, pio);


--
-- Name: thermostat_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX thermostat_name_index ON public.thermostat USING btree (name);


--
-- Name: thermostat_profile_id_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX thermostat_profile_id_name_index ON public.thermostat_profile USING btree (id, name);


--
-- Name: dutycycle_profile dutycycle_profile_dutycycle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dutycycle_profile
    ADD CONSTRAINT dutycycle_profile_dutycycle_id_fkey FOREIGN KEY (dutycycle_id) REFERENCES public.dutycycle(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: dutycycle_state dutycycle_state_dutycycle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dutycycle_state
    ADD CONSTRAINT dutycycle_state_dutycycle_id_fkey FOREIGN KEY (dutycycle_id) REFERENCES public.dutycycle(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: sensor_relhum sensor_relhum_sensor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sensor_relhum
    ADD CONSTRAINT sensor_relhum_sensor_id_fkey FOREIGN KEY (sensor_id) REFERENCES public.sensor(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: sensor_soil sensor_soil_sensor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sensor_soil
    ADD CONSTRAINT sensor_soil_sensor_id_fkey FOREIGN KEY (sensor_id) REFERENCES public.sensor(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: sensor_temperature sensor_temperature_sensor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sensor_temperature
    ADD CONSTRAINT sensor_temperature_sensor_id_fkey FOREIGN KEY (sensor_id) REFERENCES public.sensor(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: switch_cmd switch_cmd_switch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.switch_cmd
    ADD CONSTRAINT switch_cmd_switch_id_fkey FOREIGN KEY (switch_id) REFERENCES public.switch(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: switch_state switch_state_switch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.switch_state
    ADD CONSTRAINT switch_state_switch_id_fkey FOREIGN KEY (switch_id) REFERENCES public.switch(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: thermostat_profile thermostat_profile_thermostat_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thermostat_profile
    ADD CONSTRAINT thermostat_profile_thermostat_id_fkey FOREIGN KEY (thermostat_id) REFERENCES public.thermostat(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

INSERT INTO public."schema_migrations" (version) VALUES (20171217150128), (20171224164529), (20171224225113), (20171228191703), (20171229001359), (20171231182344), (20180101153253), (20180102171624), (20180102175335), (20180217212153), (20180218021213), (20180222165118), (20180222184042), (20180305193804), (20180307143400), (20180517201719), (20180708221600), (20180709181021), (20190308124055), (20190316032007), (20190317155502), (20190320124824), (20190416130912), (20190417011910), (20191018110319), (20191022013914);

