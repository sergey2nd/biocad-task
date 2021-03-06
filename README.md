# biocad-task
<details>
 <summary>Описание задачи</summary>

Наш департамент работает с большим количеством информации, которую удобно представлять в виде графа.
Это могут быть последовательности аминокислот, связанные с различными видами структур, или же химические реагенты и катализаторы, связанные с помощью реакций с получившимися продуктами.

Оказывается, на рынке уже есть графовая база данных - [neo4j](https://neo4j.com/).
Удобнее всего её установить с помощью [Docker образа](https://hub.docker.com/_/neo4j).
Несложно догадаться, что к этой базе данных существует биндинг для Haskell:
[hasbolt](http://hackage.haskell.org/package/hasbolt) и набор плюшек для него
[hasbolt-extras](http://hackage.haskell.org/package/hasbolt-extras). Некоторое представление о
работе с этим библиотеками поможет составить [доклад](https://www.youtube.com/watch?v=BPB5omKK4Tc),
а также их документация на Hackage.

**Важно.** Начиная с 4-й версии Neo4j полностью поменяли протокол и не все Haskell-библиотеки на него перешли. На текущий момент лучше использовать версию Neo4j 3.5.

### Задача

#### Задать структуру данных в Neo4j
![Структура данных](/img/haskell-test.png)
- компонент `Molecule` должен иметь поля `id :: Int`, `smiles :: String`, `iupacName :: String`;
- компонент `Reaction` должен иметь поля `id :: Int`, `name :: String`;
- компонент `Catalyst` должен иметь поля `id :: Int`, `smiles :: String`, `name :: Maybe String`;
- компонент `PRODUCT_FROM` должен иметь поле `amount :: Float`;
- компонент `ACCELERATE` должен иметь поле `temperature :: Float`, `pressure :: Float`;
- дополните структуру данных необходимыми на ваш взгляд полями;
- населите базу данных представителями (хотя бы по 20 образцов каждого вида). Данные подразумеваются совершенно синтетические.

Между записями в структурах данных могут быть различные зависимости (например, между представлением [smiles](https://en.wikipedia.org/wiki/Simplified_molecular-input_line-entry_system) и именем [IUPAC](https://en.wikipedia.org/wiki/International_Union_of_Pure_and_Applied_Chemistry)).

#### Реализовать функционал на Haskell
- создайте соответствующие типы в Haskell-библиотеке;
- напишите функцию, которая умеет принимать реацию на вход и загружать её в базу;
- напишите функцию, которая по номеру реакции в базе будет возвращать её в Haskell-объект;
- напишите функцию, которая по двум заданным молекулам ищет путь через реакции и молекулы с наименьшей длиной.

#### Подумать и предложить обобщения

В процессе развития системы будут добавляться различные компоненты, например, механизм реакции. Предлагается ответить на следующие вопросы:
- какие абстракции или вспомогательные компоненты можно ввести на уровне базы данных, чтобы новые полученные знания ладно укладывались в систему?
- какие абстракции вы бы предложили ввести в Haskell-реализацию?

</details>

## Работа с базой данных

Для работы с базой данных предназначены модули **Functions.TextRequest** и **Functions.GraphRequest**.

 #### Functions.TextRequest
 
 Модуль **Functions.TextRequest** формирует Cypher запросы на основе текстовых шаблонов. В его основе лежит **Database.Bolt** .
 Модуль экспортирует следующие функции:

* добавление реакции в БД:
```java
putReaction :: ReactionData -> BoltActionT IO (Id Reaction)
```
* извлечение реакции из БД по указанному Id:
```java
getReaction :: Id Reaction -> BoltActionT IO (Maybe ReactionData)
```
* Нахождение всех кратчайших путей через Реакции и Молекулы между молекулами:
```java
findShortPath :: Molecule -> Molecule -> BoltActionT IO [Transformation]
```
* Удаление узла реакции и связей из БД по переданному Id:
```java
deleteReaction :: Id Reaction -> BoltActionT IO ()
```
* Нахождение всех кратчайших путей через промежуточные Реакции и Молекулы между начальной и конечной Молекулами по переданным Id:
```java
findShortPathById :: Id Molecule -> Id Molecule -> BoltActionT IO [Transformation]
```
Следует отметить, что для функций *findShortPath*, *findShortPathById* важен порядок переданных агрументов, так как происходит поиск пути только в одном направлении. Если требуется найти кратчайший путь в любом из направлений, то следует использовать функцию дважды с изменением порядка агрументов.
Если оба агрумента совпадают, то возвращается путь, содержащий только переданную молекулу. Если начальная или конечная Молекулы отсутствуют в базе, то возвращается пустой список Трансформаций.

 ##### Functions.GraphQueries

Модуль **Functions.GraphRequest** основан на построении запросов из графовых шаблонов. В его основе лежит модуль **Database.Bolt.Extras.Graph**.
Модуль экспортирует только 2 функции:

* добавление реакции в БД:
```java
putReaction :: ReactionData -> BoltActionT IO (Id Reaction)
```
* извлечение реакции из БД по указанному Id:
```java
getReaction :: Id Reaction -> BoltActionT IO (Maybe ReactionData)
```


### Наполнение тестовой базы данных  

Для генерации данных и наполнения тестовой базы данных используется функция *putSampleData* из модуля **SampleData**.
Функция использует данные из файлов `Reactions.csv`,`Molecules.csv`,`Catalyst.scv` в папке `SampleData`.
```java
putSampleData :: Int -> BoltActionT IO ()
```
Ниже приведен пример использования данной функции из модуля **Main**:

```java
boltCfg :: BoltCfg
boltCfg = def { host = "localhost"
              , user = "neo4j"
              , password = "testDB"
              }

runQueryDB :: BoltActionT IO a -> IO a
runQueryDB act = bracket (connect boltCfg) close (`run` act)

main :: IO ()
main = do
  putStrLn "Enter number of generated reactions:"
  n <- read <$> getLine
  runQueryDB $ putSampleData n
```
Также модуль экспортирует функции `randomReaction`, `randomMolecule`, `randomCatalyst`, `randomProductFrom`, `randomAccelerate` для генерации составных частей реакции и `randomReactionData` для генерации реакции.

В данной библиотеке используется логика, запрещающая повторное создание или модификацию уже существующей а базе данных реакции. Если в результате генерации реакции будет повторно использоваться уже существующее имя реакции, то такая реакция не будет добавлена в тестовую БД. Это следует учитывать при выборе числа генераций, передаваемых в функцию *putSampleData*. Обычно 35 генераций достаточно для получения не менее 20 образцов каждого типа.

### Размышления по поводу дополнительных вопросов

![Расширение абстракций](/img/Reaction.png)

В структуру базы данных можно добавить компонент-узел `Mechanism` и компонент-взаимоотношение `DESCRIBES`.

Механизм реакции должен содержать информацию об интермедиатах, переходных состояниях и продуктах реакции.
Соответственно возможно введение:
* компонентов группы "Интермедиатов"
	* Карбкатион `Carbocation`
	* Карбанион `Carbanion`
	* ...
	* Нитрен `Nitrene`
* компонента "Переходного состояния" `TransitionState`
* компонента-взаимоотношение `TRANSITION_IN`
* компонента-взаимоотношение `INTERMEDIATE_IN`

В Haskell можно ввести типы данных
```java
data DESCRIBES       = DESCRIBES{..}
data TRANSITION_IN   = TRANSITION_IN{..}
data INTERMEDIATE_IN = INTERMEDIATE_IN{..}
```

```java
data Intermediate = Carbocation{..}
		  | Carbanion{..}
		  | ...
		  | Nitrene{..}
				  
data TransitionState = TransitionState{..}

data Mechanism = Mechanism [(Intermediate, INTERMEDIATE_IN)] [(TransitionState, TRANSITION_IN)]
```

Тип данных `ReactionData` следует дополнить полем `Mechanism`
```java
data ReactionData = ReactionData
	{ rdName :: Name Reaction
	, ...
	, rdMechanism :: Maybe (Mechanism, DESCRIBES)
	}
```
