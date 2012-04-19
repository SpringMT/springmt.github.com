# 「RailsとMysql」

* 2012/04/19
* @Spring_MT

# 自己紹介

* twitter id : **@Spring_MT** <br>
<image style="height: 200px" src="images/tiwtter_logo.jpg"/>

* 今は福岡の10xlabでインフラ&アプリ開発をしてます。

## 今Railsを使って開発しています。
* Railsのバージョンは3.2.2
* DBにはもちろんMysqlを使っています。
* ローカルのマシン(MBA)に、mysqld_multiを使ってmasterとslaveを立ててます
    * [Mac OSXでカジュアルにreplicationしてみる](http://spring-mt.tumblr.com/post/18485897722/mac-osx-replication)

# RailsでどうやってMysqlを操作しているか一通り見てみました

# 大枠で下記4つについてお話します。
1. Railsのmodelの構成
1. Mysqlへの接続
1. クエリーを実行
1. トランザクション


# 1. Railsのmodelの構成
* 図が入ります

# 2. Mysqlへの接続

### Mysqlへの接続

~~~
class Test < ActiveRecord::Base
  self.abstract_class = true
  establish_connection(
    :adapter  => 'mysql2',
    :encoding => "utf8",
    :reconnect => "false",
    :username => 'root',
    :password => '',
    :database => 'user',
    :socket   => '/tmp/mysql.sock',
  )
  self.table_name = 'user_data'
end
obj = Test.new
~~~

これで、コネクションが貼れます。


### Mysqlへの接続でやっていること

1. Mysql2::Client.new(config)でC APIの**mysql&#95;real&#95;connect**を使って接続  
1. **"SET SQL&#95;AUTO&#95;IS&#95;NULL=0, NAMES 'utf8', @@wait&#95;timeout = wail&#95;time"**  
を打つ  
(NAMESはencodingを設定していると追加されます)


### SET SQL&#95;AUTO&#95;IS&#95;NULL=0
* AUTO_INCREMENTを使ってると、insertを打った直後の特定のselectで挙動がおかしくなります。
* 大規模だと、AUTO_INCREMENTってほとんど使わないので、打たないケースもあるかもです。

### SET SQL&#95;AUTO&#95;IS&#95;NULLのテスト

~~~
CREATE TABLE Test (
 `ID` int(11) NOT NULL AUTO_INCREMENT,
 `Name` char(35) NOT NULL DEFAULT '',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB;
INSERT INTO Test (Name) VALUES ('test');
# SET SQL_AUTO_IS_NULL=0の場合
SELECT * FROM Test WHERE ID IS NULL;
Empty set (0.00 sec)
# SET SQL_AUTO_IS_NULL=1の場合
SELECT * FROM Test WHERE ID IS NULL;
+----+------+
| ID | Name |
+----+------+
|  4 | test |
+----+------+
1 row in set (0.00 sec)
~~~


# 3. クエリーを実行

### prepareがない
* 去年のmysql-casualのadvent calenderの@tagomorisさんのエントリでも言及されていましたが、mysql2にはprepareはありません >_<

* ActiveRecordにもありません

* なので、クエリを実行する場合(特にSQLを生で書くとき)は、自前で文字列をエスケープして、SQL文を組み立てます


### prepareがない
* エスケープには、C APIのmysql&#95;real&#95;escape&#95;stringを使っているsanitize*メソッドを使います  
(sanitizeを呼び出すたびにmysqlとやり取りします)
* エスケープは下記のようにします

~~~
string = "あいう';えお"
hash  =  { :name => "foo'bar", :group_id => 4 }
puts Test.sanitize(string)
puts Test.send(:sanitize_sql, hash)

# 実行結果
'あいう\';えお'
`City`.`name` = 'foo\'bar' AND `City`.`group_id` = 4
~~~


### クエリーを実行
* ORMがあーだこーだして、SQLを組み立てた後、最終的にexecuteメソッドが呼ばれます。

~~~
obj = Test.new
obj.connection.execute('SELECT * FROM City;')  
~~~

* クエリー実行では、mysql2経由でC APIのmysql&#95;send&#95;query経由でsqlを実行します  
(mysql&#95;real&#95;queryではないです)

### mysql&#95;send&#95;query

* mysql&#95;send&#95;queryを使っているのは、ノンブロッキングでSQLを実行させるためです 
(mysql&#95;real&#95;queryを使うと、結果が返ってくるまでまで待ちます)

* ただし、Railsでmysqlを使っている場合は、ノンブロッキングで実行するオプションはありません   
(自分は見つけられませんでした >_<)

* DBD-mysqlだと、4.019から同じような仕組みが実装されています。

### mysql&#95;send&#95;queryのソース
* sql-common/client.c

~~~
int STDCALL
mysql_send_query(MYSQL* mysql, const char* query, ulong length)
{
  DBUG_ENTER("mysql_send_query");
  DBUG_RETURN(simple_command(mysql, COM_QUERY, (uchar*) query, length, 1));
}
int STDCALL
mysql_real_query(MYSQL *mysql, const char *query, ulong length)
{
  DBUG_ENTER("mysql_real_query");                                                                                                      
  DBUG_PRINT("enter",("handle: 0x%lx", (long) mysql));
  DBUG_PRINT("query",("Query = '%-.4096s'",query));

  if (mysql_send_query(mysql,query,length))
    DBUG_RETURN(1);
  DBUG_RETURN((int) (*mysql->methods->read_query_result)(mysql));
}
~~~


### sqlを自前で実行する
* 下記みたいな感じになります。

~~~
columns = "*"
table_name = Test.table_name
where = Test.send(:sanitize_sql, {CountryCode: "USA"})
sql = "SELECT #{columns} FROM #{table_name} WHERE #{where}"

@res = obj.connection.execute(sql)
@res.map { |f| hogehogeする} # fetchrow_hashref
~~~


# 4. transactionについて
### transactionについて

~~~~
Test.transaction(:requires_new => true) do
  # 処理
end
~~~~

* ↓の用になります。

~~~
BEGIN
#処理
COMMIT or ROLLBACK
~~~

### transactionのネスト

* トランザクションのネストをすると、SAVEPOINTが打たれます。

~~~
Test.transaction(:requires_new => true) do
  # 処理 A
  Test.transaction(:requires_new => true) do
     # 処理 B
  end
end
~~~

↓

~~~
BEGIN
処理 A
SAVEPOINT active_record_1
処理 B
RELEASE SAVEPOINT active_record_1 or ROLLBACK active_record_1
COMMIT or ROLLBACK
~~~

* トランザクションのネストの使いどころがちょっと想像できないですが、こんな風になります。

### transactionについて
* RailsはXA トランザクションには対応してないです。

### 複数DB master、slaveの構成
* ここは、railsのおはなしになっちゃうのでしません


# ここまでは前フリで・・・

# 福岡でもmysql casualを開催しようと画策しています


## 一応人数はそれなりに集まりそうなので、場所とか決まったら、atnd立てます。
* 5月中旬を予定しています。
* もし、福岡の方がいましたら是非ご参加お願いします!!









