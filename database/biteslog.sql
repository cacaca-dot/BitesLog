--
-- PostgreSQL database dump
--

\restrict FAyRN0PSp6l0Jp0xo9iCwbF2RcwzHSMMZnUeWiJL6m41dWshONUUuYGB0zMjkme

-- Dumped from database version 15.18
-- Dumped by pg_dump version 15.18

-- Started on 2026-07-09 12:22:58

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

--
-- TOC entry 7 (class 2615 OID 16679)
-- Name: biteslog; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA biteslog;


ALTER SCHEMA biteslog OWNER TO postgres;

--
-- TOC entry 2 (class 3079 OID 16399)
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- TOC entry 3510 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- TOC entry 887 (class 1247 OID 16458)
-- Name: price_range_t; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.price_range_t AS ENUM (
    '$',
    '$$',
    '$$$'
);


ALTER TYPE public.price_range_t OWNER TO postgres;

--
-- TOC entry 893 (class 1247 OID 16474)
-- Name: target_type_t; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.target_type_t AS ENUM (
    'review',
    'list'
);


ALTER TYPE public.target_type_t OWNER TO postgres;

--
-- TOC entry 890 (class 1247 OID 16466)
-- Name: watchlist_priority; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.watchlist_priority AS ENUM (
    'Low',
    'Medium',
    'High'
);


ALTER TYPE public.watchlist_priority OWNER TO postgres;

--
-- TOC entry 262 (class 1255 OID 16673)
-- Name: recalc_cafe_rating(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.recalc_cafe_rating(p_cafe_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE cafes c
    SET avg_rating  = sub.avg_rating,
        visit_count = sub.visit_count
    FROM (
        SELECT ROUND(AVG(rating)::numeric, 1) AS avg_rating,
               COUNT(*)                        AS visit_count
        FROM visits
        WHERE cafe_id = p_cafe_id
    ) sub
    WHERE c.id = p_cafe_id;
END;
$$;


ALTER FUNCTION public.recalc_cafe_rating(p_cafe_id uuid) OWNER TO postgres;

--
-- TOC entry 264 (class 1255 OID 16676)
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.set_updated_at() OWNER TO postgres;

--
-- TOC entry 263 (class 1255 OID 16674)
-- Name: trg_visits_recalc(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.trg_visits_recalc() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        PERFORM recalc_cafe_rating(OLD.cafe_id);
        RETURN OLD;
    ELSE
        PERFORM recalc_cafe_rating(NEW.cafe_id);
        -- kalau cafe_id pindah saat update, recalc cafe lama juga
        IF (TG_OP = 'UPDATE' AND NEW.cafe_id <> OLD.cafe_id) THEN
            PERFORM recalc_cafe_rating(OLD.cafe_id);
        END IF;
        RETURN NEW;
    END IF;
END;
$$;


ALTER FUNCTION public.trg_visits_recalc() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 217 (class 1259 OID 16495)
-- Name: cafes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cafes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(150) NOT NULL,
    category character varying(50),
    address text,
    city character varying(100),
    price_range public.price_range_t,
    latitude double precision,
    longitude double precision,
    avg_rating numeric(2,1),
    visit_count integer DEFAULT 0 NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT avg_rating_range CHECK (((avg_rating IS NULL) OR ((avg_rating >= 0.5) AND (avg_rating <= 5.0))))
);


ALTER TABLE public.cafes OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 16645)
-- Name: comments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.comments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    target_type public.target_type_t NOT NULL,
    target_id uuid NOT NULL,
    comment_text text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT comment_not_empty CHECK ((length(TRIM(BOTH FROM comment_text)) > 0))
);


ALTER TABLE public.comments OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 16614)
-- Name: follows; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.follows (
    follower_id uuid NOT NULL,
    following_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT no_self_follow CHECK ((follower_id <> following_id))
);


ALTER TABLE public.follows OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 16631)
-- Name: likes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.likes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    target_type public.target_type_t NOT NULL,
    target_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.likes OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 16593)
-- Name: list_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.list_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    list_id uuid NOT NULL,
    cafe_id uuid NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    note text
);


ALTER TABLE public.list_items OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 16577)
-- Name: lists; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lists (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    title character varying(150) NOT NULL,
    description text,
    is_public boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.lists OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 16532)
-- Name: reviews; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.reviews (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    cafe_id uuid NOT NULL,
    rating numeric(2,1),
    review_text text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT review_not_empty CHECK (((rating IS NOT NULL) OR (review_text IS NOT NULL))),
    CONSTRAINT review_rating_range CHECK (((rating IS NULL) OR ((rating >= 0.5) AND (rating <= 5.0) AND ((rating * (2)::numeric) = floor((rating * (2)::numeric))))))
);


ALTER TABLE public.reviews OWNER TO postgres;

--
-- TOC entry 216 (class 1259 OID 16479)
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    full_name character varying(100) NOT NULL,
    username character varying(20) NOT NULL,
    email character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    bio text,
    avatar_url text,
    is_private boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT username_format CHECK (((username)::text ~ '^[A-Za-z0-9_]{3,20}$'::text))
);


ALTER TABLE public.users OWNER TO postgres;

--
-- TOC entry 218 (class 1259 OID 16511)
-- Name: visits; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.visits (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    cafe_id uuid NOT NULL,
    visit_date date DEFAULT CURRENT_DATE NOT NULL,
    rating numeric(2,1),
    review text,
    favorite_drink character varying(100),
    price character varying(50),
    photo_path text,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT visit_rating_range CHECK (((rating IS NULL) OR ((rating >= 0.5) AND (rating <= 5.0) AND ((rating * (2)::numeric) = floor((rating * (2)::numeric))))))
);


ALTER TABLE public.visits OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 16555)
-- Name: watchlist; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.watchlist (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    cafe_id uuid NOT NULL,
    priority public.watchlist_priority DEFAULT 'Medium'::public.watchlist_priority NOT NULL,
    reason text,
    tiktok_url text,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.watchlist OWNER TO postgres;

--
-- TOC entry 3496 (class 0 OID 16495)
-- Dependencies: 217
-- Data for Name: cafes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cafes (id, name, category, address, city, price_range, latitude, longitude, avg_rating, visit_count, created_by, created_at) FROM stdin;
10c3595c-b045-48c4-853e-78d2d705168e	Specialty Corner	Coffee	\N	Bandung	$$$	\N	\N	\N	0	964ff35e-1c2d-42f9-a6b9-5244e127552e	2026-07-06 21:11:58.383238+07
7100b76b-0869-4342-93a5-ddf4dcb394ea	Kopi Matcha House	Matcha	\N	Jakarta	$$	\N	\N	4.5	1	c3a4d72a-64e5-430d-bccb-8329260b657e	2026-07-06 21:11:58.383238+07
\.


--
-- TOC entry 3504 (class 0 OID 16645)
-- Dependencies: 225
-- Data for Name: comments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.comments (id, user_id, target_type, target_id, comment_text, created_at) FROM stdin;
\.


--
-- TOC entry 3502 (class 0 OID 16614)
-- Dependencies: 223
-- Data for Name: follows; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.follows (follower_id, following_id, created_at) FROM stdin;
c3a4d72a-64e5-430d-bccb-8329260b657e	964ff35e-1c2d-42f9-a6b9-5244e127552e	2026-07-06 21:11:58.383238+07
\.


--
-- TOC entry 3503 (class 0 OID 16631)
-- Dependencies: 224
-- Data for Name: likes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.likes (id, user_id, target_type, target_id, created_at) FROM stdin;
\.


--
-- TOC entry 3501 (class 0 OID 16593)
-- Dependencies: 222
-- Data for Name: list_items; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.list_items (id, list_id, cafe_id, "position", note) FROM stdin;
\.


--
-- TOC entry 3500 (class 0 OID 16577)
-- Dependencies: 221
-- Data for Name: lists; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.lists (id, user_id, title, description, is_public, created_at, updated_at) FROM stdin;
\.


--
-- TOC entry 3498 (class 0 OID 16532)
-- Dependencies: 219
-- Data for Name: reviews; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.reviews (id, user_id, cafe_id, rating, review_text, created_at) FROM stdin;
\.


--
-- TOC entry 3495 (class 0 OID 16479)
-- Dependencies: 216
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, full_name, username, email, password_hash, bio, avatar_url, is_private, created_at, updated_at) FROM stdin;
c3a4d72a-64e5-430d-bccb-8329260b657e	Kikoyu	kikoyu	kikoyu@mail.com	$2b$10$contohHashKikoyu	Matcha lover	\N	f	2026-07-06 21:11:58.383238+07	2026-07-06 21:11:58.383238+07
964ff35e-1c2d-42f9-a6b9-5244e127552e	Dimas	dimas	dimas@mail.com	$2b$10$contohHashDimas	Specialty coffee geek	\N	f	2026-07-06 21:11:58.383238+07	2026-07-06 21:11:58.383238+07
a2354819-87bf-4888-acec-1a600796dfaf	Test User	testuser123	testuser@mail.com	$2b$10$KQJX6BM.Ol0EXk6ryg.kmOFT0xNgOkV7Ifmb9YmXL2FtRMWeyvHle	\N	\N	f	2026-07-06 21:57:03.186595+07	2026-07-06 21:57:03.186595+07
\.


--
-- TOC entry 3497 (class 0 OID 16511)
-- Dependencies: 218
-- Data for Name: visits; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.visits (id, user_id, cafe_id, visit_date, rating, review, favorite_drink, price, photo_path, notes, created_at) FROM stdin;
b5732632-d353-4992-8f7e-29400ffcf881	c3a4d72a-64e5-430d-bccb-8329260b657e	7100b76b-0869-4342-93a5-ddf4dcb394ea	2026-07-06	4.5	Matcha-nya enak banget	Hojicha Latte	\N	\N	\N	2026-07-06 21:11:58.383238+07
\.


--
-- TOC entry 3499 (class 0 OID 16555)
-- Dependencies: 220
-- Data for Name: watchlist; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.watchlist (id, user_id, cafe_id, priority, reason, tiktok_url, notes, created_at) FROM stdin;
\.


--
-- TOC entry 3298 (class 2606 OID 16505)
-- Name: cafes cafes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cafes
    ADD CONSTRAINT cafes_pkey PRIMARY KEY (id);


--
-- TOC entry 3334 (class 2606 OID 16654)
-- Name: comments comments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_pkey PRIMARY KEY (id);


--
-- TOC entry 3326 (class 2606 OID 16620)
-- Name: follows follows_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.follows
    ADD CONSTRAINT follows_pkey PRIMARY KEY (follower_id, following_id);


--
-- TOC entry 3330 (class 2606 OID 16637)
-- Name: likes likes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.likes
    ADD CONSTRAINT likes_pkey PRIMARY KEY (id);


--
-- TOC entry 3322 (class 2606 OID 16601)
-- Name: list_items list_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.list_items
    ADD CONSTRAINT list_items_pkey PRIMARY KEY (id);


--
-- TOC entry 3319 (class 2606 OID 16587)
-- Name: lists lists_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lists
    ADD CONSTRAINT lists_pkey PRIMARY KEY (id);


--
-- TOC entry 3309 (class 2606 OID 16542)
-- Name: reviews reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_pkey PRIMARY KEY (id);


--
-- TOC entry 3332 (class 2606 OID 16639)
-- Name: likes uniq_like; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.likes
    ADD CONSTRAINT uniq_like UNIQUE (user_id, target_type, target_id);


--
-- TOC entry 3324 (class 2606 OID 16603)
-- Name: list_items uniq_list_cafe; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.list_items
    ADD CONSTRAINT uniq_list_cafe UNIQUE (list_id, cafe_id);


--
-- TOC entry 3311 (class 2606 OID 16544)
-- Name: reviews uniq_user_cafe_review; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT uniq_user_cafe_review UNIQUE (user_id, cafe_id);


--
-- TOC entry 3314 (class 2606 OID 16566)
-- Name: watchlist uniq_user_cafe_watchlist; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.watchlist
    ADD CONSTRAINT uniq_user_cafe_watchlist UNIQUE (user_id, cafe_id);


--
-- TOC entry 3292 (class 2606 OID 16494)
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- TOC entry 3294 (class 2606 OID 16490)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- TOC entry 3296 (class 2606 OID 16492)
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- TOC entry 3305 (class 2606 OID 16521)
-- Name: visits visits_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.visits
    ADD CONSTRAINT visits_pkey PRIMARY KEY (id);


--
-- TOC entry 3316 (class 2606 OID 16564)
-- Name: watchlist watchlist_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.watchlist
    ADD CONSTRAINT watchlist_pkey PRIMARY KEY (id);


--
-- TOC entry 3299 (class 1259 OID 16672)
-- Name: idx_cafes_category; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cafes_category ON public.cafes USING btree (category);


--
-- TOC entry 3300 (class 1259 OID 16671)
-- Name: idx_cafes_city; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cafes_city ON public.cafes USING btree (city);


--
-- TOC entry 3335 (class 1259 OID 16670)
-- Name: idx_comments_target; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_comments_target ON public.comments USING btree (target_type, target_id);


--
-- TOC entry 3327 (class 1259 OID 16668)
-- Name: idx_follows_following; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_follows_following ON public.follows USING btree (following_id);


--
-- TOC entry 3328 (class 1259 OID 16669)
-- Name: idx_likes_target; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_likes_target ON public.likes USING btree (target_type, target_id);


--
-- TOC entry 3320 (class 1259 OID 16667)
-- Name: idx_list_items_list; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_list_items_list ON public.list_items USING btree (list_id);


--
-- TOC entry 3317 (class 1259 OID 16666)
-- Name: idx_lists_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_lists_user ON public.lists USING btree (user_id);


--
-- TOC entry 3306 (class 1259 OID 16663)
-- Name: idx_reviews_cafe; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_reviews_cafe ON public.reviews USING btree (cafe_id);


--
-- TOC entry 3307 (class 1259 OID 16664)
-- Name: idx_reviews_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_reviews_user ON public.reviews USING btree (user_id);


--
-- TOC entry 3301 (class 1259 OID 16661)
-- Name: idx_visits_cafe; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_visits_cafe ON public.visits USING btree (cafe_id);


--
-- TOC entry 3302 (class 1259 OID 16662)
-- Name: idx_visits_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_visits_date ON public.visits USING btree (visit_date DESC);


--
-- TOC entry 3303 (class 1259 OID 16660)
-- Name: idx_visits_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_visits_user ON public.visits USING btree (user_id);


--
-- TOC entry 3312 (class 1259 OID 16665)
-- Name: idx_watchlist_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_watchlist_user ON public.watchlist USING btree (user_id);


--
-- TOC entry 3352 (class 2620 OID 16678)
-- Name: lists lists_set_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER lists_set_updated_at BEFORE UPDATE ON public.lists FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- TOC entry 3350 (class 2620 OID 16677)
-- Name: users users_set_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER users_set_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- TOC entry 3351 (class 2620 OID 16675)
-- Name: visits visits_recalc_rating; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER visits_recalc_rating AFTER INSERT OR DELETE OR UPDATE ON public.visits FOR EACH ROW EXECUTE FUNCTION public.trg_visits_recalc();


--
-- TOC entry 3336 (class 2606 OID 16506)
-- Name: cafes cafes_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cafes
    ADD CONSTRAINT cafes_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- TOC entry 3349 (class 2606 OID 16655)
-- Name: comments comments_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 3346 (class 2606 OID 16621)
-- Name: follows follows_follower_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.follows
    ADD CONSTRAINT follows_follower_id_fkey FOREIGN KEY (follower_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 3347 (class 2606 OID 16626)
-- Name: follows follows_following_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.follows
    ADD CONSTRAINT follows_following_id_fkey FOREIGN KEY (following_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 3348 (class 2606 OID 16640)
-- Name: likes likes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.likes
    ADD CONSTRAINT likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 3344 (class 2606 OID 16609)
-- Name: list_items list_items_cafe_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.list_items
    ADD CONSTRAINT list_items_cafe_id_fkey FOREIGN KEY (cafe_id) REFERENCES public.cafes(id) ON DELETE CASCADE;


--
-- TOC entry 3345 (class 2606 OID 16604)
-- Name: list_items list_items_list_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.list_items
    ADD CONSTRAINT list_items_list_id_fkey FOREIGN KEY (list_id) REFERENCES public.lists(id) ON DELETE CASCADE;


--
-- TOC entry 3343 (class 2606 OID 16588)
-- Name: lists lists_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lists
    ADD CONSTRAINT lists_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 3339 (class 2606 OID 16550)
-- Name: reviews reviews_cafe_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_cafe_id_fkey FOREIGN KEY (cafe_id) REFERENCES public.cafes(id) ON DELETE CASCADE;


--
-- TOC entry 3340 (class 2606 OID 16545)
-- Name: reviews reviews_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 3337 (class 2606 OID 16527)
-- Name: visits visits_cafe_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.visits
    ADD CONSTRAINT visits_cafe_id_fkey FOREIGN KEY (cafe_id) REFERENCES public.cafes(id) ON DELETE CASCADE;


--
-- TOC entry 3338 (class 2606 OID 16522)
-- Name: visits visits_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.visits
    ADD CONSTRAINT visits_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 3341 (class 2606 OID 16572)
-- Name: watchlist watchlist_cafe_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.watchlist
    ADD CONSTRAINT watchlist_cafe_id_fkey FOREIGN KEY (cafe_id) REFERENCES public.cafes(id) ON DELETE CASCADE;


--
-- TOC entry 3342 (class 2606 OID 16567)
-- Name: watchlist watchlist_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.watchlist
    ADD CONSTRAINT watchlist_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


-- Completed on 2026-07-09 12:22:59

--
-- PostgreSQL database dump complete
--

\unrestrict FAyRN0PSp6l0Jp0xo9iCwbF2RcwzHSMMZnUeWiJL6m41dWshONUUuYGB0zMjkme

