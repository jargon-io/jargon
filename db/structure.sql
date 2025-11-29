SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: vector; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;


--
-- Name: EXTENSION vector; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION vector IS 'vector data type and ivfflat and hnsw access methods';


--
-- Name: nanoid(integer, text, double precision); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.nanoid(size integer DEFAULT 21, alphabet text DEFAULT '_-0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'::text, additionalbytesfactor double precision DEFAULT 1.6) RETURNS text
    LANGUAGE plpgsql PARALLEL SAFE
    AS $$
DECLARE
    alphabetArray  text[];
    alphabetLength int := 64;
    mask           int := 63;
    step           int := 34;
BEGIN
    IF size IS NULL OR size < 1 THEN
        RAISE EXCEPTION 'The size must be defined and greater than 0!';
    END IF;

    IF alphabet IS NULL OR length(alphabet) = 0 OR length(alphabet) > 255 THEN
        RAISE EXCEPTION 'The alphabet can''t be undefined, zero or bigger than 255 symbols!';
    END IF;

    IF additionalBytesFactor IS NULL OR additionalBytesFactor < 1 THEN
        RAISE EXCEPTION 'The additional bytes factor can''t be less than 1!';
    END IF;

    alphabetArray := regexp_split_to_array(alphabet, '');
    alphabetLength := array_length(alphabetArray, 1);
    mask := (2 << cast(floor(log(alphabetLength - 1) / log(2)) as int)) - 1;
    step := cast(ceil(additionalBytesFactor * mask * size / alphabetLength) AS int);

    IF step > 1024 THEN
        step := 1024; -- The step size % can''t be bigger then 1024!
    END IF;

    RETURN nanoid_optimized(size, alphabet, mask, step);
END
$$;


--
-- Name: nanoid_optimized(integer, text, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.nanoid_optimized(size integer, alphabet text, mask integer, step integer) RETURNS text
    LANGUAGE plpgsql PARALLEL SAFE
    AS $$
DECLARE
    idBuilder      text := '';
    counter        int  := 0;
    bytes          bytea;
    alphabetIndex  int;
    alphabetArray  text[];
    alphabetLength int  := 64;
BEGIN
    alphabetArray := regexp_split_to_array(alphabet, '');
    alphabetLength := array_length(alphabetArray, 1);

    LOOP
        bytes := gen_random_bytes(step);
        FOR counter IN 0..step - 1
            LOOP
                alphabetIndex := (get_byte(bytes, counter) & mask) + 1;
                IF alphabetIndex <= alphabetLength THEN
                    idBuilder := idBuilder || alphabetArray[alphabetIndex];
                    IF length(idBuilder) = size THEN
                        RETURN idBuilder;
                    END IF;
                END IF;
            END LOOP;
    END LOOP;
END
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: articles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.articles (
    id bigint NOT NULL,
    title character varying,
    url character varying NOT NULL,
    author character varying,
    published_at timestamp(6) without time zone,
    summary text,
    text text,
    image_url character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    embedding public.vector(1536),
    slug character varying NOT NULL
);


--
-- Name: articles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.articles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: articles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.articles_id_seq OWNED BY public.articles.id;


--
-- Name: cluster_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cluster_memberships (
    id bigint NOT NULL,
    cluster_id bigint NOT NULL,
    clusterable_type character varying NOT NULL,
    clusterable_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: cluster_memberships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.cluster_memberships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cluster_memberships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.cluster_memberships_id_seq OWNED BY public.cluster_memberships.id;


--
-- Name: clusters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.clusters (
    id bigint NOT NULL,
    clusterable_type character varying NOT NULL,
    name character varying,
    slug character varying NOT NULL,
    summary text,
    status integer DEFAULT 0 NOT NULL,
    embedding public.vector(1536),
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    image_url character varying,
    body text,
    snippet text
);


--
-- Name: clusters_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.clusters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: clusters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.clusters_id_seq OWNED BY public.clusters.id;


--
-- Name: insights; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.insights (
    id bigint NOT NULL,
    article_id bigint NOT NULL,
    title character varying,
    body text,
    snippet text,
    status integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    embedding public.vector(1536),
    slug character varying NOT NULL
);


--
-- Name: insights_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.insights_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: insights_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.insights_id_seq OWNED BY public.insights.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: thread_articles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.thread_articles (
    id bigint NOT NULL,
    research_thread_id bigint NOT NULL,
    article_id bigint NOT NULL,
    relevance_note text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: thread_articles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.thread_articles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: thread_articles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.thread_articles_id_seq OWNED BY public.thread_articles.id;


--
-- Name: threads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.threads (
    id bigint NOT NULL,
    insight_id bigint NOT NULL,
    query text NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    article_id bigint,
    slug character varying NOT NULL
);


--
-- Name: threads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.threads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: threads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.threads_id_seq OWNED BY public.threads.id;


--
-- Name: web_search_articles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.web_search_articles (
    id bigint NOT NULL,
    web_search_id bigint NOT NULL,
    article_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: web_search_articles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.web_search_articles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: web_search_articles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.web_search_articles_id_seq OWNED BY public.web_search_articles.id;


--
-- Name: web_searches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.web_searches (
    id bigint NOT NULL,
    query character varying NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: web_searches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.web_searches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: web_searches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.web_searches_id_seq OWNED BY public.web_searches.id;


--
-- Name: articles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articles ALTER COLUMN id SET DEFAULT nextval('public.articles_id_seq'::regclass);


--
-- Name: cluster_memberships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cluster_memberships ALTER COLUMN id SET DEFAULT nextval('public.cluster_memberships_id_seq'::regclass);


--
-- Name: clusters id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clusters ALTER COLUMN id SET DEFAULT nextval('public.clusters_id_seq'::regclass);


--
-- Name: insights id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.insights ALTER COLUMN id SET DEFAULT nextval('public.insights_id_seq'::regclass);


--
-- Name: thread_articles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thread_articles ALTER COLUMN id SET DEFAULT nextval('public.thread_articles_id_seq'::regclass);


--
-- Name: threads id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.threads ALTER COLUMN id SET DEFAULT nextval('public.threads_id_seq'::regclass);


--
-- Name: web_search_articles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.web_search_articles ALTER COLUMN id SET DEFAULT nextval('public.web_search_articles_id_seq'::regclass);


--
-- Name: web_searches id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.web_searches ALTER COLUMN id SET DEFAULT nextval('public.web_searches_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: articles articles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articles
    ADD CONSTRAINT articles_pkey PRIMARY KEY (id);


--
-- Name: cluster_memberships cluster_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cluster_memberships
    ADD CONSTRAINT cluster_memberships_pkey PRIMARY KEY (id);


--
-- Name: clusters clusters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clusters
    ADD CONSTRAINT clusters_pkey PRIMARY KEY (id);


--
-- Name: insights insights_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.insights
    ADD CONSTRAINT insights_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: thread_articles thread_articles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thread_articles
    ADD CONSTRAINT thread_articles_pkey PRIMARY KEY (id);


--
-- Name: threads threads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.threads
    ADD CONSTRAINT threads_pkey PRIMARY KEY (id);


--
-- Name: web_search_articles web_search_articles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.web_search_articles
    ADD CONSTRAINT web_search_articles_pkey PRIMARY KEY (id);


--
-- Name: web_searches web_searches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.web_searches
    ADD CONSTRAINT web_searches_pkey PRIMARY KEY (id);


--
-- Name: idx_cluster_memberships_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_cluster_memberships_uniqueness ON public.cluster_memberships USING btree (clusterable_type, clusterable_id);


--
-- Name: index_articles_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_articles_on_slug ON public.articles USING btree (slug);


--
-- Name: index_articles_on_url; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_articles_on_url ON public.articles USING btree (url);


--
-- Name: index_cluster_memberships_on_cluster_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cluster_memberships_on_cluster_id ON public.cluster_memberships USING btree (cluster_id);


--
-- Name: index_cluster_memberships_on_clusterable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cluster_memberships_on_clusterable ON public.cluster_memberships USING btree (clusterable_type, clusterable_id);


--
-- Name: index_clusters_on_clusterable_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clusters_on_clusterable_type ON public.clusters USING btree (clusterable_type);


--
-- Name: index_clusters_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_clusters_on_slug ON public.clusters USING btree (slug);


--
-- Name: index_insights_on_article_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_insights_on_article_id ON public.insights USING btree (article_id);


--
-- Name: index_insights_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_insights_on_slug ON public.insights USING btree (slug);


--
-- Name: index_thread_articles_on_article_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thread_articles_on_article_id ON public.thread_articles USING btree (article_id);


--
-- Name: index_thread_articles_on_research_thread_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thread_articles_on_research_thread_id ON public.thread_articles USING btree (research_thread_id);


--
-- Name: index_thread_articles_on_research_thread_id_and_article_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_thread_articles_on_research_thread_id_and_article_id ON public.thread_articles USING btree (research_thread_id, article_id);


--
-- Name: index_threads_on_insight_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_threads_on_insight_id ON public.threads USING btree (insight_id);


--
-- Name: index_threads_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_threads_on_slug ON public.threads USING btree (slug);


--
-- Name: index_web_search_articles_on_article_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_web_search_articles_on_article_id ON public.web_search_articles USING btree (article_id);


--
-- Name: index_web_search_articles_on_web_search_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_web_search_articles_on_web_search_id ON public.web_search_articles USING btree (web_search_id);


--
-- Name: thread_articles fk_rails_11c79ccb57; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thread_articles
    ADD CONSTRAINT fk_rails_11c79ccb57 FOREIGN KEY (article_id) REFERENCES public.articles(id);


--
-- Name: web_search_articles fk_rails_1e9a52c862; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.web_search_articles
    ADD CONSTRAINT fk_rails_1e9a52c862 FOREIGN KEY (article_id) REFERENCES public.articles(id);


--
-- Name: thread_articles fk_rails_5c2c73703b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thread_articles
    ADD CONSTRAINT fk_rails_5c2c73703b FOREIGN KEY (research_thread_id) REFERENCES public.threads(id);


--
-- Name: web_search_articles fk_rails_711ba9ba8c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.web_search_articles
    ADD CONSTRAINT fk_rails_711ba9ba8c FOREIGN KEY (web_search_id) REFERENCES public.web_searches(id);


--
-- Name: cluster_memberships fk_rails_83c1a6a50e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cluster_memberships
    ADD CONSTRAINT fk_rails_83c1a6a50e FOREIGN KEY (cluster_id) REFERENCES public.clusters(id);


--
-- Name: threads fk_rails_ce6ff6a226; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.threads
    ADD CONSTRAINT fk_rails_ce6ff6a226 FOREIGN KEY (insight_id) REFERENCES public.insights(id);


--
-- Name: threads fk_rails_daafb51834; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.threads
    ADD CONSTRAINT fk_rails_daafb51834 FOREIGN KEY (article_id) REFERENCES public.articles(id);


--
-- Name: insights fk_rails_fcb882bec4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.insights
    ADD CONSTRAINT fk_rails_fcb882bec4 FOREIGN KEY (article_id) REFERENCES public.articles(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20251129160954'),
('20251129153217'),
('20251129151925'),
('20251129144943'),
('20251129144246'),
('20251129144127'),
('20251129142556'),
('20251129141526'),
('20251129045418'),
('20251129042358'),
('20251129042341'),
('20251128222601'),
('20251128210721'),
('20251128203952'),
('20251128200427'),
('20251128195711'),
('20251128195639'),
('20251128194539');

