-- ============================================================================
-- Práctica 11 — Fase 4: planes de ejecución y tiempos en la BD del servidor
-- Ejecutar en: Supabase Dashboard > SQL Editor (proyecto de CHAAC XANAB).
-- Todas las consultas son de LECTURA salvo el bloque DB-02, que revierte todo
-- (no deja cambios).
-- IMPORTANTE: el SQL Editor sólo muestra el resultado de la ÚLTIMA sentencia y
-- se detiene en el primer error. Selecciona UN bloque a la vez (Q1, Q2, …) y
-- pulsa "Run" (Ctrl+Enter ejecuta sólo lo seleccionado).
-- Copiar "Planning Time" y "Execution Time" de cada resultado al INFORME §4.3.
-- ============================================================================

-- Q1. Catálogo (GET /api/productos -> ProductosService.findAll)
EXPLAIN (ANALYZE, BUFFERS)
SELECT p.id, p.name, p.description, p.price, p.original_price, p.stock, p.image_url,
       p.sizes, p.badge, p.activo, c.id, c.slug, c.name
FROM productos p LEFT JOIN categorias c ON c.id = p.categoria_id
WHERE p.activo = true
ORDER BY p.created_at DESC;

-- Q2. Login (AuthService.login) — búsqueda por correo, debe usar usuarios_email_key
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, email, role, name, password_hash, email_verified, activo, deleted_at,
       failed_login_attempts, locked_until
FROM usuarios WHERE email = 'cliente@example.com';

-- Q3. Historial (GET /api/compras/mis-compras) — debe usar idx_compras_user
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.id, c.total, c.status, c.created_at, i.id, i.name, i.price, i.size, i.quantity, i.image_url
FROM compras c LEFT JOIN compras_items i ON i.compra_id = c.id
WHERE c.user_id = (SELECT id FROM usuarios LIMIT 1)
ORDER BY c.created_at DESC;

-- Q4. Bitácora por correo (las filas de la prueba de carga) — NO hay índice en usuario_email
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM bitacora WHERE usuario_email = 'practica11-carga@example.invalid';

-- Índices existentes (evidencia de §4.2)
SELECT tablename, indexname, indexdef FROM pg_indexes
WHERE schemaname = 'public' AND tablename IN ('productos','usuarios','compras','compras_items','bitacora')
ORDER BY tablename, indexname;

-- Restricciones (NOT NULL / UNIQUE / FK / CHECK)
SELECT conrelid::regclass AS tabla, conname, pg_get_constraintdef(oid) AS definicion
FROM pg_constraint
WHERE connamespace = 'public'::regnamespace
  AND conrelid::regclass::text IN ('productos','usuarios','compras','compras_items')
ORDER BY 1, 2;

-- RLS: ¿qué tablas tienen Row Level Security activo?
SELECT relname AS tabla, relrowsecurity AS rls_activo
FROM pg_class WHERE relnamespace = 'public'::regnamespace AND relkind = 'r' ORDER BY 1;

-- DB-02: integridad — cada sentencia DEBE ser rechazada.
-- pg_temp.intentar() ejecuta la sentencia dentro de un sub-bloque, atrapa el
-- error y lo devuelve como texto; si la sentencia se aceptara, la revierte a
-- propósito. Así corren todas en una sola tabla de resultados y no queda
-- ningún cambio (la función es temporal y desaparece al cerrar la sesión).
CREATE OR REPLACE FUNCTION pg_temp.intentar(sentencia text) RETURNS text
LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE sentencia;
  RAISE EXCEPTION 'P11_ACEPTADA';
EXCEPTION WHEN others THEN
  IF SQLERRM = 'P11_ACEPTADA' THEN
    RETURN 'ACEPTADA (revertida) -> la restricción NO existe';
  END IF;
  RETURN 'RECHAZADA ' || SQLSTATE || ': ' || SQLERRM;
END $$;

SELECT prueba, pg_temp.intentar(sentencia) AS resultado
FROM (VALUES
  ('FK productos.categoria_id',
   $q$INSERT INTO productos (categoria_id, name, price, stock) VALUES (gen_random_uuid(), 'x', 10, 1)$q$),
  ('CHECK productos.stock >= 0',
   $q$UPDATE productos SET stock = -1 WHERE id = (SELECT id FROM productos LIMIT 1)$q$),
  ('CHECK productos.price >= 0',
   $q$UPDATE productos SET price = -5 WHERE id = (SELECT id FROM productos LIMIT 1)$q$),
  ('NOT NULL productos.name',
   $q$INSERT INTO productos (categoria_id, name, price, stock) SELECT id, NULL, 10, 1 FROM categorias LIMIT 1$q$),
  ('UNIQUE usuarios.email',
   $q$INSERT INTO usuarios (name, email, password_hash) SELECT 'dup', email, 'x' FROM usuarios LIMIT 1$q$),
  ('CHECK compras_items.quantity > 0',
   $q$INSERT INTO compras_items (compra_id, producto_id, name, price, size, quantity)
      SELECT c.id, p.id, 'x', 1, '26', 0 FROM compras c, productos p LIMIT 1$q$),
  ('CHECK compras.status IN (...)',
   $q$UPDATE compras SET status = 'regalado' WHERE id = (SELECT id FROM compras LIMIT 1)$q$)
) AS t(prueba, sentencia);

-- Limpieza de la prueba de carga (60 filas LOGIN_FALLIDO de practica11/scripts/carga.mjs)
-- DELETE FROM bitacora WHERE usuario_email = 'practica11-carga@example.invalid';
