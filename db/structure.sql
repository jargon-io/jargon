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
    url character varying,
    author character varying,
    published_at timestamp(6) without time zone,
    summary text,
    text text,
    image_url character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    embedding public.vector(1536),
    slug character varying NOT NULL,
    content_type integer DEFAULT 0 NOT NULL,
    parent_id bigint
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
-- Name: insights; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.insights (
    id bigint NOT NULL,
    article_id bigint,
    title character varying,
    body text,
    snippet text,
    status integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    embedding public.vector(1536),
    slug character varying NOT NULL,
    parent_id bigint
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
-- Name: search_articles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.search_articles (
    id bigint NOT NULL,
    search_id bigint NOT NULL,
    article_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: search_articles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.search_articles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: search_articles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.search_articles_id_seq OWNED BY public.search_articles.id;


--
-- Name: searches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.searches (
    id bigint NOT NULL,
    slug character varying NOT NULL,
    query text NOT NULL,
    search_query text,
    search_query_embedding public.vector(1536),
    summary text,
    snippet text,
    embedding public.vector(1536),
    status integer DEFAULT 0 NOT NULL,
    source_type character varying,
    source_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: searches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.searches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: searches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.searches_id_seq OWNED BY public.searches.id;


--
-- Name: threads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.threads (
    id bigint NOT NULL,
    query text NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    slug character varying NOT NULL,
    subject_type character varying,
    subject_id bigint
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
-- Name: articles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articles ALTER COLUMN id SET DEFAULT nextval('public.articles_id_seq'::regclass);


--
-- Name: insights id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.insights ALTER COLUMN id SET DEFAULT nextval('public.insights_id_seq'::regclass);


--
-- Name: search_articles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_articles ALTER COLUMN id SET DEFAULT nextval('public.search_articles_id_seq'::regclass);


--
-- Name: searches id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.searches ALTER COLUMN id SET DEFAULT nextval('public.searches_id_seq'::regclass);


--
-- Name: threads id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.threads ALTER COLUMN id SET DEFAULT nextval('public.threads_id_seq'::regclass);


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
-- Name: search_articles search_articles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_articles
    ADD CONSTRAINT search_articles_pkey PRIMARY KEY (id);


--
-- Name: searches searches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.searches
    ADD CONSTRAINT searches_pkey PRIMARY KEY (id);


--
-- Name: threads threads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.threads
    ADD CONSTRAINT threads_pkey PRIMARY KEY (id);


--
-- Name: index_articles_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_articles_on_parent_id ON public.articles USING btree (parent_id);


--
-- Name: index_articles_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_articles_on_slug ON public.articles USING btree (slug);


--
-- Name: index_articles_on_url; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_articles_on_url ON public.articles USING btree (url);


--
-- Name: index_insights_on_article_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_insights_on_article_id ON public.insights USING btree (article_id);


--
-- Name: index_insights_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_insights_on_parent_id ON public.insights USING btree (parent_id);


--
-- Name: index_insights_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_insights_on_slug ON public.insights USING btree (slug);


--
-- Name: index_search_articles_on_article_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_search_articles_on_article_id ON public.search_articles USING btree (article_id);


--
-- Name: index_search_articles_on_search_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_search_articles_on_search_id ON public.search_articles USING btree (search_id);


--
-- Name: index_search_articles_on_search_id_and_article_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_search_articles_on_search_id_and_article_id ON public.search_articles USING btree (search_id, article_id);


--
-- Name: index_searches_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_searches_on_slug ON public.searches USING btree (slug);


--
-- Name: index_searches_on_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_searches_on_source ON public.searches USING btree (source_type, source_id);


--
-- Name: index_searches_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_searches_on_status ON public.searches USING btree (status);


--
-- Name: index_threads_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_threads_on_slug ON public.threads USING btree (slug);


--
-- Name: index_threads_on_subject; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_threads_on_subject ON public.threads USING btree (subject_type, subject_id);


--
-- Name: search_articles fk_rails_59c83cbdf9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_articles
    ADD CONSTRAINT fk_rails_59c83cbdf9 FOREIGN KEY (article_id) REFERENCES public.articles(id);


--
-- Name: insights fk_rails_5dd65deb05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.insights
    ADD CONSTRAINT fk_rails_5dd65deb05 FOREIGN KEY (parent_id) REFERENCES public.insights(id);


--
-- Name: search_articles fk_rails_d62aa3fc9f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_articles
    ADD CONSTRAINT fk_rails_d62aa3fc9f FOREIGN KEY (search_id) REFERENCES public.searches(id);


--
-- Name: articles fk_rails_d8ed45d2e9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articles
    ADD CONSTRAINT fk_rails_d8ed45d2e9 FOREIGN KEY (parent_id) REFERENCES public.articles(id);


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
('20251201014802'),
('20251130224542'),
('20251130223634'),
('20251130223631'),
('20251130165333'),
('20251130165254'),
('20251130163534'),
('20251129221540'),
('20251129192004'),
('20251129164403'),
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

