-- Supabase 프로젝트의 SQL Editor에서 실행하세요.

-- ============================================================
-- 처음 테이블을 만드는 경우 (신규 Supabase 프로젝트)
-- ============================================================
create table if not exists events (
  id bigint generated always as identity primary key,
  event_id text not null,     -- 이벤트 구분값. index.html CONFIG.eventSlug 와 일치해야 함 (예: '2026-08-sua')
  panel text not null,        -- index.html CONFIG.panels 의 id 값과 일치해야 함 (예: 'd1')
  sort_order int not null default 0,  -- 같은 panel 안에서의 정렬 순서
  time text,                  -- 예: '09:00-09:30'
  title text not null,        -- 예: '아침식사'
  detail text,                -- 예: '식당 1층'
  created_at timestamptz default now()
);

-- 행 단위 보안(RLS) 활성화
alter table events enable row level security;

-- 누구나 읽기(SELECT)는 허용 — 공개 일정 페이지이므로
create policy "public can read events"
  on events for select
  using (true);

-- 쓰기(INSERT/UPDATE/DELETE)는 기본적으로 막혀 있음(정책 없음 = 거부).
-- 로그인(Supabase Auth)한 관리자만 admin.html에서 추가/수정/삭제 가능하도록 허용
create policy "authenticated can write events"
  on events for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

-- 일정에 이미지 첨부 (선택사항 — admin.html에서 사진 첨부 시 여기에 URL이 저장됨)
alter table events add column if not exists image_url text;

-- 예시 데이터 (원하는 대로 수정/삭제하세요)
insert into events (event_id, panel, sort_order, time, title, detail) values
  ('2026-08-sua', 'd1', 1, '09:00-10:00', '집합 및 출발', '정문 앞에서 모임'),
  ('2026-08-sua', 'd1', 2, '12:00-13:00', '점심식사', null),
  ('2026-08-sua', 'd2', 1, '08:00-08:30', '기상 및 아침식사', null);


-- ============================================================
-- 일정 이미지 첨부 기능 (admin.html에서 사진 업로드)
-- 먼저 Storage 메뉴에서 'event-images'라는 이름의 Public 버킷을 만든 뒤 아래 실행
-- ============================================================
-- 로그인한 관리자만 업로드/수정/삭제 가능 (다운로드는 버킷이 Public이라 정책 없이도 누구나 가능)
create policy "authenticated can upload event images"
  on storage.objects for insert
  with check (bucket_id = 'event-images' and auth.role() = 'authenticated');

create policy "authenticated can update event images"
  on storage.objects for update
  using (bucket_id = 'event-images' and auth.role() = 'authenticated');

create policy "authenticated can delete event images"
  on storage.objects for delete
  using (bucket_id = 'event-images' and auth.role() = 'authenticated');


-- ============================================================
-- 갤러리 (누구나 사진/영상을 올릴 수 있는 독립된 앨범 — 일정에 첨부한 사진과는 별개)
-- 먼저 Storage 메뉴에서 'gallery-uploads'라는 이름의 Public 버킷을 만들고,
-- 버킷 설정에서 File size limit을 100MB로 지정한 뒤 아래 실행
-- ============================================================
create table if not exists gallery_media (
  id bigint generated always as identity primary key,
  event_id text not null,       -- index.html CONFIG.eventSlug 와 일치해야 함
  media_url text not null,
  media_type text not null,     -- 'image' 또는 'video'
  created_at timestamptz default now()
);

alter table gallery_media enable row level security;

-- 누구나 읽기 가능 (갤러리는 공개)
create policy "public can read gallery_media"
  on gallery_media for select
  using (true);

-- 누구나(로그인 안 해도) 업로드 가능 — 파일 자체는 페이지의 용량 제한(사진 50MB/영상 100MB)으로 걸러짐
create policy "anyone can insert gallery_media"
  on gallery_media for insert
  with check (true);

-- 삭제는 로그인한 관리자만 (부적절한 업로드 정리용)
create policy "authenticated can delete gallery_media"
  on gallery_media for delete
  using (auth.role() = 'authenticated');

-- 수정도 로그인한 관리자만 (기존 사진 워터마크 재처리 시 media_url 교체용)
create policy "authenticated can update gallery_media"
  on gallery_media for update
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

-- Storage: 누구나 업로드, 삭제는 관리자만
create policy "anyone can upload to gallery bucket"
  on storage.objects for insert
  with check (bucket_id = 'gallery-uploads');

create policy "authenticated can delete from gallery bucket"
  on storage.objects for delete
  using (bucket_id = 'gallery-uploads' and auth.role() = 'authenticated');


-- ============================================================
-- 헤더(아이콘/제목/부제목)를 Supabase에서 직접 수정할 수 있게 하는 테이블
-- 이벤트당 딱 한 행만 있으면 됨. 행이 없으면 index.html의 CONFIG 기본값이 그대로 쓰임
-- ============================================================
create table if not exists event_meta (
  event_id text primary key,  -- index.html CONFIG.eventSlug 와 일치해야 함 (예: '2026-08-sua')
  icon text,                  -- 헤더 상단 아이콘 이모지 (예: '🗓️')
  org_name text,              -- 큰 제목 (예: '수아연아랑')
  event_name text,            -- 부제목 앞부분 (예: '여름 수련회')
  date_range_text text,       -- 부제목 뒷부분 (예: '2026. 8. 14(금) ~ 8. 17(월)')
  updated_at timestamptz default now()
);

alter table event_meta enable row level security;

create policy "public can read event_meta"
  on event_meta for select
  using (true);

-- 지금 이벤트의 헤더 값 (필요한 값만 채우면 됨 — 나머지는 CONFIG 기본값 사용)
insert into event_meta (event_id, icon, org_name, event_name, date_range_text) values
  ('2026-08-sua', '🗓️', '수아연아랑', '일정명', '2026. 8. 14(금) ~ 8. 17(월)');


-- ============================================================
-- "버튼만으로 새 이벤트 자동 생성" 기능
-- event_meta에 시작일/종료일 컬럼을 추가해서, 이 두 값만으로
-- /e/index.html(공용 이벤트 페이지)이 날짜별 탭을 자동 계산해서 만들어줌.
-- 폴더/파일을 새로 만들 필요 없이 허브 페이지의 "+ 새 이벤트 만들기" 버튼만으로 끝남.
-- ============================================================
alter table event_meta add column if not exists start_date date;
alter table event_meta add column if not exists end_date date;

-- 관리자(로그인한 사람)는 event_meta를 직접 추가/수정할 수 있게 허용
-- (지금까지는 읽기만 허용돼 있었음 — 새 이벤트 생성 버튼이 이 테이블에 행을 추가해야 해서 필요)
create policy "authenticated can write event_meta"
  on event_meta for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

-- 기존 2026-08-sua 행에도 시작일/종료일을 채워두면 좋음 (선택사항)
update event_meta set start_date = '2026-08-14', end_date = '2026-08-17' where event_id = '2026-08-sua';


-- ============================================================
-- 이미 events 테이블이 있고 event_id 컬럼만 추가하는 경우
-- (여러 이벤트를 앞으로 계속 만들기로 하면서 기존 테이블을 재사용할 때 1회만 실행)
-- ============================================================
-- 1) 컬럼 추가 (일단 nullable로)
alter table events add column if not exists event_id text;

-- 2) 기존 행들을 첫 번째 이벤트로 채워넣기 — 'YOUR_FIRST_EVENT_SLUG'를 실제 slug로 바꿔서 실행
-- update events set event_id = 'YOUR_FIRST_EVENT_SLUG' where event_id is null;

-- 3) 다 채워진 걸 확인한 뒤, 앞으로는 비워둘 수 없게 고정
-- alter table events alter column event_id set not null;


-- ============================================================
-- 새 이벤트를 추가할 때마다
-- ============================================================
-- 1. events 테이블에 새 event_id 값으로 일정 행들을 추가 (Table Editor 또는 insert 문)
-- 2. event_meta 테이블에 새 event_id로 헤더(아이콘/제목/부제목) 행 추가 (선택사항, 없으면 CONFIG 기본값 사용)
-- 3. index.html 을 새 폴더(예: 2027-01-newevent/)에 복사하고 CONFIG.eventSlug 를 새 값으로 수정
-- 4. 루트 index.html(허브 페이지)의 EVENTS 배열에 새 이벤트 한 줄 추가
