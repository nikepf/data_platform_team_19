from pyspark.sql import SparkSession, functions as F


def transform(source):
    typed = source.select(
        F.upper(F.trim('product')).alias('product'),
        F.col('quantity').cast('int').alias('quantity'),
        F.col('price').cast('decimal(10,2)').alias('price'),
        F.to_date('dt', 'yyyy-MM-dd').alias('day'),
    )
    valid = typed.filter(
        (F.col('quantity') > 0)
        & (F.col('price') >= 0)
        & (F.length('product') > 0)
        & F.col('day').isNotNull()
    )
    return (
        valid.withColumn('dt', F.date_format('day', 'yyyy-MM-dd'))
        .groupBy('dt', 'product')
        .agg(
            F.count('*').alias('orders'),
            F.sum('quantity').alias('quantity'),
            F.sum(F.col('quantity') * F.col('price')).cast('decimal(12,2)').alias('revenue'),
        )
        .select('product', 'orders', 'quantity', 'revenue', 'dt')
    )


def main():
    spark = SparkSession.builder.appName('hw4-sales').getOrCreate()
    try:
        assert spark.sparkContext.master == 'yarn'
        assert spark.sparkContext._jsc.hadoopConfiguration().get('fs.defaultFS') == 'hdfs://team-19-nn:9000'
        source = (
            spark.read.option('header', True).option('mode', 'FAILFAST')
            .schema('id STRING, product STRING, quantity STRING, price STRING, dt STRING')
            .csv('hdfs://team-19-nn:9000/user/team/hw4/input/data.csv')
        )
        (
            transform(source).write.mode('overwrite').partitionBy('dt')
            .parquet('hdfs://team-19-nn:9000/user/team/hw4/sales_daily')
        )
    finally:
        spark.stop()


if __name__ == '__main__':
    main()
