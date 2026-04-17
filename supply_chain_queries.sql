-- ============================================================
-- TEDARİK ZİNCİRİ SQL ANALİZİ
-- Veri: Kaggle Supply Chain Data
-- Endüstri Mühendisliği — Staj Hazırlık Projesi
-- ============================================================

-- ── SORGU 1: Genel Bakış ────────────────────────────────────
SELECT 
    COUNT(*)                            AS toplam_urun,
    COUNT(DISTINCT supplier_name)       AS tedarikci_sayisi,
    COUNT(DISTINCT location)            AS lokasyon_sayisi,
    COUNT(DISTINCT product_type)        AS urun_tipi_sayisi,
    ROUND(AVG(price), 2)                AS ort_fiyat,
    ROUND(SUM(revenue_generated), 0)    AS toplam_gelir,
    ROUND(AVG(defect_rates), 3)         AS ort_hata_orani,
    ROUND(AVG(stock_levels), 1)         AS ort_stok_seviyesi
FROM supply_chain;

-- ── SORGU 2: Ürün Tipi Bazlı Özet ──────────────────────────
SELECT 
    product_type                            AS urun_tipi,
    COUNT(*)                                AS urun_sayisi,
    ROUND(AVG(price), 2)                    AS ort_fiyat,
    ROUND(SUM(revenue_generated), 0)        AS toplam_gelir,
    ROUND(AVG(stock_levels), 1)             AS ort_stok,
    ROUND(AVG(defect_rates), 3)             AS ort_hata_orani,
    ROUND(AVG(lead_times), 1)               AS ort_temin_suresi
FROM supply_chain
GROUP BY product_type
ORDER BY toplam_gelir DESC;

-- ── SORGU 3: Tedarikçi Performans Skorecard ─────────────────
SELECT 
    supplier_name                               AS tedarikci,
    COUNT(*)                                    AS urun_sayisi,
    ROUND(AVG(lead_time), 1)                    AS ort_temin_suresi,
    ROUND(AVG(defect_rates), 3)                 AS ort_hata_orani,
    ROUND(AVG(production_volumes), 0)           AS ort_uretim_hacmi,
    ROUND(SUM(revenue_generated), 0)            AS toplam_gelir,
    ROUND(AVG(manufacturing_costs), 2)          AS ort_uretim_maliyeti,
    ROUND(
        (30 - AVG(lead_time)) / 30.0 * 40 +
        (5  - AVG(defect_rates)) / 5.0 * 40 +
        AVG(production_volumes) / 985.0 * 20
    , 1)                                        AS performans_skoru
FROM supply_chain
GROUP BY supplier_name
ORDER BY performans_skoru DESC;

-- ── SORGU 4: Stok Durumu & Yeniden Sipariş Noktası ─────────
SELECT 
    sku,
    product_type,
    supplier_name,
    stock_levels                                AS mevcut_stok,
    lead_times                                  AS temin_suresi_gun,
    order_quantities                            AS siparis_miktari,
    ROUND(number_of_products_sold / 52.0, 1)   AS haftalik_talep,
    ROUND(number_of_products_sold / 52.0 
          * lead_times / 7.0, 0)               AS yeniden_siparis_noktasi,
    CASE 
        WHEN stock_levels < (number_of_products_sold / 52.0 * lead_times / 7.0)
        THEN 'KRITIK - Siparis Ver!'
        WHEN stock_levels < (number_of_products_sold / 52.0 * lead_times / 7.0) * 1.5
        THEN 'Dusuk - Izle'
        ELSE 'Normal'
    END                                         AS stok_durumu
FROM supply_chain
ORDER BY stok_durumu DESC, stock_levels ASC;

-- ── SORGU 5: ABC Analizi (CTE + WINDOW FUNCTION) ───────────
WITH gelir_sirali AS (
    SELECT 
        sku,
        product_type,
        supplier_name,
        revenue_generated,
        SUM(revenue_generated) OVER (ORDER BY revenue_generated DESC) AS kumulatif_gelir,
        SUM(revenue_generated) OVER ()                                 AS toplam_gelir
    FROM supply_chain
),
abc AS (
    SELECT *,
        ROUND(kumulatif_gelir / toplam_gelir * 100, 2) AS kumulatif_pct,
        CASE 
            WHEN kumulatif_gelir / toplam_gelir * 100 <= 80 THEN 'A - Yuksek Deger'
            WHEN kumulatif_gelir / toplam_gelir * 100 <= 95 THEN 'B - Orta Deger'
            ELSE 'C - Dusuk Deger'
        END AS abc_sinifi
    FROM gelir_sirali
)
SELECT 
    abc_sinifi,
    COUNT(*)                            AS urun_sayisi,
    ROUND(SUM(revenue_generated), 0)    AS toplam_gelir,
    ROUND(AVG(revenue_generated), 0)    AS ort_gelir
FROM abc
GROUP BY abc_sinifi
ORDER BY toplam_gelir DESC;

-- ── SORGU 6: Taşıma Modu Maliyet & Verimlilik ──────────────
SELECT 
    transportation_modes                        AS tasima_modu,
    COUNT(*)                                    AS siparis_sayisi,
    ROUND(AVG(shipping_costs), 2)               AS ort_kargo_maliyeti,
    ROUND(AVG(shipping_times), 1)               AS ort_teslimat_suresi,
    ROUND(AVG(revenue_generated), 0)            AS ort_gelir,
    ROUND(AVG(shipping_costs) / 
          AVG(revenue_generated) * 100, 2)      AS kargo_gelir_orani_pct,
    ROUND(AVG(defect_rates), 3)                 AS ort_hata_orani
FROM supply_chain
GROUP BY transportation_modes
ORDER BY ort_kargo_maliyeti ASC;

-- ── SORGU 7: WINDOW FUNCTION — Tedarikçi İçi Sıralama ──────
SELECT 
    supplier_name,
    sku,
    product_type,
    revenue_generated,
    RANK() OVER (
        PARTITION BY supplier_name 
        ORDER BY revenue_generated DESC
    )                                           AS tedarikci_ici_sira,
    ROUND(revenue_generated / SUM(revenue_generated) 
          OVER (PARTITION BY supplier_name) * 100, 1) AS tedarikci_gelir_payi_pct
FROM supply_chain
ORDER BY supplier_name, tedarikci_ici_sira;

-- ── SORGU 8: Tek Tedarikçi Riski ───────────────────────────
WITH urun_tedarikci AS (
    SELECT 
        product_type,
        supplier_name,
        COUNT(*) AS urun_sayisi,
        ROUND(SUM(revenue_generated), 0) AS gelir
    FROM supply_chain
    GROUP BY product_type, supplier_name
),
toplam AS (
    SELECT product_type, SUM(urun_sayisi) AS toplam
    FROM urun_tedarikci
    GROUP BY product_type
)
SELECT 
    u.product_type                  AS urun_tipi,
    u.supplier_name                 AS tedarikci,
    u.urun_sayisi,
    u.gelir,
    ROUND(u.urun_sayisi * 100.0 
          / t.toplam, 1)            AS pazar_payi_pct,
    CASE 
        WHEN u.urun_sayisi * 100.0 / t.toplam >= 60 
        THEN 'YUKSEK RISK'
        WHEN u.urun_sayisi * 100.0 / t.toplam >= 40 
        THEN 'ORTA RISK'
        ELSE 'NORMAL'
    END                             AS risk_seviyesi
FROM urun_tedarikci u
JOIN toplam t ON u.product_type = t.product_type
ORDER BY pazar_payi_pct DESC;
