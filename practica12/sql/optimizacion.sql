-- ============================================================================
-- Práctica 12 — Optimización de base de datos (Supabase > SQL Editor)
-- Ejecuta CADA BLOQUE POR SEPARADO (selecciona el bloque y Ctrl+Enter).
-- Nada de este archivo borra ni modifica datos existentes.
-- ============================================================================


-- ── BLOQUE A · ANTES: plan del historial paginado del usuario P12 ────────────
-- (Copia el resultado "QUERY PLAN" completo.)
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, total, status, created_at
FROM compras
WHERE user_id = (SELECT id FROM usuarios WHERE email = 'p12.carga@example.invalid')
ORDER BY created_at DESC
LIMIT 20;


-- ── BLOQUE B · CREAR LAS OPTIMIZACIONES ─────────────────────────────────────
-- B1. Idempotencia: un reintento con la misma llave no crea otra compra.
ALTER TABLE compras ADD COLUMN IF NOT EXISTS idempotency_key TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS uq_compras_usuario_idem
  ON compras (user_id, idempotency_key) WHERE idempotency_key IS NOT NULL;

-- B2. Historial paginado: el índice entrega las compras ya ordenadas por fecha.
CREATE INDEX IF NOT EXISTS idx_compras_usuario_fecha ON compras (user_id, created_at DESC);

-- B3. Descuento de stock atómico (una sola sentencia: no hay "leer y luego escribir").
CREATE OR REPLACE FUNCTION public.descontar_stock(p_producto_id uuid, p_cantidad int)
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_stock int;
BEGIN
  UPDATE productos SET stock = stock - p_cantidad
   WHERE id = p_producto_id AND activo AND stock >= p_cantidad
   RETURNING stock INTO v_stock;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'STOCK_INSUFICIENTE' USING ERRCODE = 'P0001';
  END IF;
  RETURN v_stock;
END $$;

-- B4. Compra completa en UNA transacción y UN viaje de red:
--     idempotencia + dirección + cabecera + renglones + descuento atómico + total.
CREATE OR REPLACE FUNCTION public.crear_compra(
  p_user_id uuid,
  p_items jsonb,
  p_direccion jsonb DEFAULT NULL,
  p_direccion_id uuid DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_compra compras%ROWTYPE;
  v_prod   productos%ROWTYPE;
  v_dir    uuid := p_direccion_id;
  v_total  numeric(10,2) := 0;
  v_item   jsonb;
  v_cant   int;
  v_repe   boolean := false;
BEGIN
  -- 1) Idempotencia: si la llave ya existe, se devuelve la compra original.
  IF p_idempotency_key IS NOT NULL THEN
    SELECT * INTO v_compra FROM compras WHERE user_id = p_user_id AND idempotency_key = p_idempotency_key;
    v_repe := FOUND;
  END IF;

  IF NOT v_repe THEN
    IF jsonb_typeof(p_items) IS DISTINCT FROM 'array' OR jsonb_array_length(p_items) = 0 THEN
      RAISE EXCEPTION 'La compra no tiene productos' USING ERRCODE = 'P0003';
    END IF;

    -- 2) Dirección principal (insertar o actualizar).
    IF v_dir IS NULL AND p_direccion IS NOT NULL THEN
      SELECT id INTO v_dir FROM usuarios_direcciones
       WHERE user_id = p_user_id AND es_principal LIMIT 1 FOR UPDATE;
      IF v_dir IS NULL THEN
        INSERT INTO usuarios_direcciones (user_id, es_principal, calle, numero_ext, numero_int, colonia, ciudad, estado, codigo_postal, pais)
        VALUES (p_user_id, true, p_direccion->>'calle', p_direccion->>'numero_ext', p_direccion->>'numero_int',
                p_direccion->>'colonia', p_direccion->>'ciudad', p_direccion->>'estado', p_direccion->>'codigo_postal',
                COALESCE(p_direccion->>'pais', 'México'))
        RETURNING id INTO v_dir;
      ELSE
        UPDATE usuarios_direcciones SET
          calle = p_direccion->>'calle', numero_ext = p_direccion->>'numero_ext', numero_int = p_direccion->>'numero_int',
          colonia = p_direccion->>'colonia', ciudad = p_direccion->>'ciudad', estado = p_direccion->>'estado',
          codigo_postal = p_direccion->>'codigo_postal', pais = COALESCE(p_direccion->>'pais', pais)
         WHERE id = v_dir;
      END IF;
    END IF;

    -- 3) Cabecera.
    INSERT INTO compras (user_id, direccion_id, total, idempotency_key)
    VALUES (p_user_id, v_dir, 0, p_idempotency_key)
    RETURNING * INTO v_compra;

    -- 4) Renglones con descuento atómico (orden fijo por producto para evitar interbloqueos).
    FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) ORDER BY value->>'producto_id' LOOP
      v_cant := (v_item->>'quantity')::int;
      UPDATE productos SET stock = stock - v_cant
       WHERE id = (v_item->>'producto_id')::uuid AND activo AND stock >= v_cant
       RETURNING * INTO v_prod;
      IF NOT FOUND THEN
        SELECT * INTO v_prod FROM productos WHERE id = (v_item->>'producto_id')::uuid AND activo;
        IF FOUND THEN
          RAISE EXCEPTION 'Stock insuficiente para "%". Disponible: %, pedido: %', v_prod.name, v_prod.stock, v_cant
            USING ERRCODE = 'P0001';
        END IF;
        RAISE EXCEPTION 'Producto % no encontrado o inactivo', v_item->>'producto_id' USING ERRCODE = 'P0002';
      END IF;
      INSERT INTO compras_items (compra_id, producto_id, name, price, size, quantity, image_url)
      VALUES (v_compra.id, v_prod.id, v_prod.name, v_prod.price, v_item->>'size', v_cant, v_prod.image_url);
      v_total := v_total + v_prod.price * v_cant;
    END LOOP;

    UPDATE compras SET total = v_total WHERE id = v_compra.id RETURNING * INTO v_compra;
  END IF;

  RETURN jsonb_build_object(
    'repetida', v_repe,
    'compra', jsonb_build_object('id', v_compra.id, 'total', v_compra.total, 'status', v_compra.status, 'created_at', v_compra.created_at),
    'items', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('compra_id', ci.compra_id, 'producto_id', ci.producto_id, 'name', ci.name,
                                          'price', ci.price, 'size', ci.size, 'quantity', ci.quantity, 'image_url', ci.image_url))
        FROM compras_items ci WHERE ci.compra_id = v_compra.id), '[]'::jsonb));
END $$;

-- B5. Seguridad: sólo el backend (service_role) puede llamar estas funciones.
--     Sin esto, cualquiera con la llave pública (anon) podría invocarlas vía /rest/v1/rpc.
REVOKE ALL ON FUNCTION public.descontar_stock(uuid, int) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.crear_compra(uuid, jsonb, jsonb, uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.descontar_stock(uuid, int) TO service_role;
GRANT EXECUTE ON FUNCTION public.crear_compra(uuid, jsonb, jsonb, uuid, text) TO service_role;

-- Verificación (debe devolver 2 filas y 2 índices):
SELECT 'funcion' AS tipo, proname AS nombre FROM pg_proc WHERE proname IN ('crear_compra', 'descontar_stock')
UNION ALL
SELECT 'indice', indexname FROM pg_indexes WHERE indexname IN ('uq_compras_usuario_idem', 'idx_compras_usuario_fecha');


-- ── BLOQUE C · DESPUÉS: el mismo plan del bloque A ──────────────────────────
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, total, status, created_at
FROM compras
WHERE user_id = (SELECT id FROM usuarios WHERE email = 'p12.carga@example.invalid')
ORDER BY created_at DESC
LIMIT 20;


-- ── BLOQUE D · ESCALA: el mismo efecto con 200,000 compras sintéticas ────────
-- Usa tablas TEMPORALES (desaparecen al terminar; no tocan tus datos) y
-- devuelve en una sola tabla el plan sin índice y con índice.
CREATE OR REPLACE FUNCTION pg_temp.p12_escala() RETURNS TABLE(fase text, linea text) LANGUAGE plpgsql AS $$
DECLARE r record; u uuid := '00000000-0000-4000-8000-000000000123';
BEGIN
  DROP TABLE IF EXISTS pg_temp.compras_p12;
  CREATE TEMP TABLE compras_p12 AS
    SELECT gen_random_uuid() AS id,
           ('00000000-0000-4000-8000-' || lpad((g % 2000)::text, 12, '0'))::uuid AS user_id,
           (random() * 5000)::numeric(10,2) AS total,
           now() - (g || ' minutes')::interval AS created_at
      FROM generate_series(1, 200000) g;
  CREATE INDEX ON compras_p12 (user_id);          -- equivalente a idx_compras_user (ya existía)
  ANALYZE compras_p12;
  FOR r IN EXECUTE format('EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM compras_p12 WHERE user_id = %L ORDER BY created_at DESC LIMIT 20', u) LOOP
    fase := '1 sin índice compuesto'; linea := r."QUERY PLAN"; RETURN NEXT;
  END LOOP;
  CREATE INDEX ON compras_p12 (user_id, created_at DESC);  -- equivalente a idx_compras_usuario_fecha
  ANALYZE compras_p12;
  FOR r IN EXECUTE format('EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM compras_p12 WHERE user_id = %L ORDER BY created_at DESC LIMIT 20', u) LOOP
    fase := '2 con índice compuesto'; linea := r."QUERY PLAN"; RETURN NEXT;
  END LOOP;
END $$;
SELECT * FROM pg_temp.p12_escala();


-- ── LIMPIEZA AL TERMINAR LA PRÁCTICA (opcional) ─────────────────────────────
-- Los datos de prueba (usuario/producto P12 y sus compras) los borra:
--   node practica12/datos_prueba.js borrar      (desde backend-chaac-xanab)
-- Las funciones e índices se QUEDAN: son la optimización en producción.
