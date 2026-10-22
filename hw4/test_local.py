from decimal import Decimal
from pathlib import Path
from tempfile import TemporaryDirectory

from pyspark.sql import SparkSession
from pipeline import transform

spark = SparkSession.builder.master('local[2]').appName('hw4-test').getOrCreate()
try:
    source = (
        spark.read.option('header', True)
        .schema('id STRING, product STRING, quantity STRING, price STRING, dt STRING')
        .csv(str(Path(__file__).with_name('data.csv')))
    )
    result = transform(source)
    assert [tuple(row) for row in result.orderBy('dt', 'product').collect()] == [
        ('BOOK', 2, 3, Decimal('250.00'), '2026-10-21'),
        ('PEN', 1, 3, Decimal('30.00'), '2026-10-21'),
        ('BOOK', 1, 2, Decimal('240.00'), '2026-10-22'),
        ('PEN', 1, 2, Decimal('30.00'), '2026-10-22'),
    ]
    with TemporaryDirectory() as directory:
        target = Path(directory) / 'sales'
        result.write.partitionBy('dt').parquet(str(target))
        assert sorted(path.name for path in target.glob('dt=*')) == ['dt=2026-10-21', 'dt=2026-10-22']
        assert spark.read.parquet(str(target)).count() == 4
finally:
    spark.stop()
