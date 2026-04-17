# Tedarik Zinciri SQL Analizi
SQLite ile tedarik zinciri analizi | ABC analizi, stok yönetimi, tedarikçi skorecard | CTE + Window Functions | Google Colab
## Proje Hakkında

Bu projede Kaggle'dan alınan gerçek bir tedarik zinciri veri seti üzerinde **SQLite** kullanılarak kapsamlı bir veri analizi gerçekleştirilmiştir. Temel SQL sorgularından başlayarak CTE (Common Table Expressions) ve Window Functions gibi ileri seviye teknikler uygulanmış; sonuçlar Python ve Matplotlib ile görselleştirilmiştir.

Projenin amacı; bir endüstri mühendisinin tedarik zinciri yönetiminde ihtiyaç duyduğu stok analizi, tedarikçi değerlendirmesi ve risk tespiti gibi analizleri SQL kullanarak nasıl yapabileceğini göstermektir.

---

## Veri Seti

| Özellik | Değer |
|---------|-------|
| Kaynak | [Kaggle — Supply Chain Data](https://www.kaggle.com/datasets/laurinbrechter/supply-chain-data) |
| Kayıt Sayısı | 100 SKU |
| Sütun Sayısı | 24 |
| Konu | Ürün, tedarikçi, stok, kargo, üretim ve gelir bilgileri |

### Veri Setindeki Temel Değişkenler

| Sütun | Açıklama |
|-------|----------|
| `product_type` | Ürün kategorisi (haircare, skincare, cosmetics) |
| `sku` | Stok tutma birimi kodu |
| `price` | Ürün fiyatı |
| `stock_levels` | Mevcut stok miktarı |
| `lead_times` | Müşteriye temin süresi (gün) |
| `order_quantities` | Sipariş miktarı |
| `supplier_name` | Tedarikçi adı |
| `revenue_generated` | Üretilen gelir |
| `defect_rates` | Hata oranı |
| `manufacturing_costs` | Üretim maliyeti |
| `shipping_costs` | Kargo maliyeti |
| `transportation_modes` | Taşıma modu (hava, kara, deniz, tren) |

---

## Dosyalar

| Dosya | Açıklama |
|-------|----------|
| `supply_chain_sql.ipynb` | Google Colab notebook — SQL + Python + görselleştirme |
| `supply_chain_queries.sql` | Tüm SQL sorgularını içeren saf SQL dosyası |
| `supply_chain_data.csv` | Ham veri (Kaggle'dan indirilmeli) |

---

## Yapılan Analizler

### Sorgu 1 — Genel Bakış
Veri setinin temel istatistiklerini özetleyen genel bakış sorgusu. Toplam ürün sayısı, tedarikçi sayısı, ortalama fiyat, toplam gelir ve ortalama hata oranı hesaplanmıştır.

```sql
SELECT 
    COUNT(*)                            AS toplam_urun,
    COUNT(DISTINCT supplier_name)       AS tedarikci_sayisi,
    ROUND(SUM(revenue_generated), 0)    AS toplam_gelir,
    ROUND(AVG(defect_rates), 3)         AS ort_hata_orani
FROM supply_chain;
```

---

### Sorgu 2 — Ürün Tipi Bazlı Özet
Her ürün kategorisi için ortalama fiyat, toplam gelir, ortalama stok seviyesi ve hata oranı karşılaştırılmıştır. Hangi ürün tipinin en fazla gelir ürettiği ve en düşük hata oranına sahip olduğu belirlenmiştir.

---

### Sorgu 3 — Tedarikçi Performans Skorecard
Her tedarikçi için temin süresi, hata oranı ve üretim hacmi verilerinden oluşan ağırlıklı bir **performans skoru** hesaplanmıştır.

**Formül:**
```
Performans Skoru = 
  (30 - Ort. Temin Süresi) / 30 × 40  [Hız ağırlığı]
+ (5  - Ort. Hata Oranı)  / 5  × 40  [Kalite ağırlığı]
+ Ort. Üretim Hacmi / 985  × 20       [Kapasite ağırlığı]
```

Bu skor, tedarikçilerin hız, kalite ve kapasite boyutlarında karşılaştırılmasına olanak tanır.

---

### Sorgu 4 — Stok Durumu & Yeniden Sipariş Noktası
Her ürün için haftalık talep ve temin süresi baz alınarak **Yeniden Sipariş Noktası (ROP)** hesaplanmış; mevcut stok seviyesi bu eşikle karşılaştırılarak her ürün `Kritik`, `Düşük` veya `Normal` olarak sınıflandırılmıştır.

**Formül:**
```
ROP = (Yıllık Satış / 52) × (Temin Süresi / 7)
```

```sql
CASE 
    WHEN stock_levels < ROP       THEN 'KRITIK - Siparis Ver!'
    WHEN stock_levels < ROP * 1.5 THEN 'Dusuk - Izle'
    ELSE 'Normal'
END AS stok_durumu
```

---

### Sorgu 5 — ABC Analizi (CTE + Window Function)
Gelire göre sıralanan ürünler için kümülatif gelir hesaplanmış ve her ürün ABC sınıfına atanmıştır. Bu sorgu **CTE (WITH...AS)** ve **Window Function (SUM OVER ORDER BY)** kullanılarak yazılmıştır.

| Sınıf | Kriter | Anlamı |
|-------|--------|--------|
| A | İlk %80 gelir | Yüksek değerli — yakından takip et |
| B | %80–95 arası | Orta değerli — periyodik kontrol |
| C | Son %5 | Düşük değerli — minimum stok tut |

---

### Sorgu 6 — Taşıma Modu Maliyet & Verimlilik Analizi
Hava, kara, deniz ve tren taşımacılığı karşılaştırılmış; ortalama kargo maliyeti, teslimat süresi ve kargo/gelir oranı hesaplanmıştır. Hangi taşıma modunun maliyet-etkin olduğu belirlenmiştir.

---

### Sorgu 7 — Window Function: Tedarikçi İçi Sıralama
Her tedarikçinin kendi ürünleri arasında gelire göre sıralama yapılmış; her ürünün tedarikçi toplam gelirine katkı payı hesaplanmıştır.

```sql
RANK() OVER (PARTITION BY supplier_name ORDER BY revenue_generated DESC)
```

Bu sorgu, **PARTITION BY** ile gruplama ve **RANK()** ile sıralama tekniklerini bir arada kullanmaktadır.

---

### Sorgu 8 — Tek Tedarikçi Riski (JOIN + CTE)
Her ürün tipi için tedarikçilerin pazar payı hesaplanmış ve yüksek bağımlılık riski tespit edilmiştir. Pazar payı %60 üzerindeki tedarikçiler `YÜKSEK RİSK` olarak işaretlenmiştir.

---

## Görselleştirmeler

Notebook içinde SQL sorgu sonuçları 6 farklı grafikle görselleştirilmiştir:

1. **Tedarikçi Performans Skoru** — Bar chart
2. **Ürün Tipi Gelir Dağılımı** — Pie chart
3. **Stok Durumu Dağılımı** — Bar chart (Kritik/Düşük/Normal)
4. **ABC Analizi** — Pie chart
5. **Taşıma Modu Analizi** — Grouped bar chart
6. **Temin Süresi vs Hata Oranı** — Bubble chart

---

## Kullanılan SQL Teknikleri

| Teknik | Kullanıldığı Sorgu |
|--------|-------------------|
| `SELECT`, `WHERE`, `GROUP BY`, `ORDER BY` | Tüm sorgular |
| `ROUND`, `AVG`, `SUM`, `COUNT` | 1, 2, 3, 6 |
| `CASE WHEN / THEN / ELSE` | 4, 8 |
| `CTE (WITH ... AS)` | 5, 8 |
| `WINDOW FUNCTION — SUM() OVER()` | 5 |
| `WINDOW FUNCTION — RANK() OVER (PARTITION BY)` | 7 |
| `JOIN` | 8 |
| `Subquery` | 5 |

---

## Kurulum & Çalıştırma

### Google Colab (Önerilen)
1. [colab.research.google.com](https://colab.research.google.com) → **File → Upload notebook** → `supply_chain_sql.ipynb`
2. İlk hücreyi çalıştır → `supply_chain_data.csv` yükle
3. **Runtime → Run all**

### Yerel Ortam
```bash
pip install pandas matplotlib
python -c "import sqlite3; print('SQLite hazır')"
jupyter notebook supply_chain_sql.ipynb
```

> SQLite Python'a dahili gelir, ek kurulum gerekmez.

---

## Bulgular

- **En iyi tedarikçi:** Supplier 1 (Performans skoru: 56.1)
- **En düşük hata oranı:** Supplier 1 (%1.80)
- **En hızlı temin:** Supplier 1 (14.78 gün)
- **Kritik stok riski:** Birden fazla SKU yeniden sipariş noktasının altında
- **En verimli taşıma:** Road (en düşük kargo/gelir oranı)

---

## Kullanılan Araçlar

![Python](https://img.shields.io/badge/Python-3776AB?style=flat&logo=python&logoColor=white)
![SQLite](https://img.shields.io/badge/SQLite-003B57?style=flat&logo=sqlite&logoColor=white)
![Pandas](https://img.shields.io/badge/Pandas-150458?style=flat&logo=pandas&logoColor=white)
![Google Colab](https://img.shields.io/badge/Google_Colab-F9AB00?style=flat&logo=googlecolab&logoColor=white)

---

*Endüstri Mühendisliği — Staj Hazırlık Projesi*
