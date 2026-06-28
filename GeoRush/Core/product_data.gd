extends Resource
class_name ProductData

# As formas exatas do seu Documento de Design
enum ShapeType { ESFERA, CILINDRO, PARALELEPIPEDO, CUBO }
enum CategoryType { FRUTA, DOCE, BEBIDA, CONSERVA, MERCEARIA, LATICINIOS, FRIOS, MATINAIS }

@export var product_name: String = "Novo Produto"
@export var shape: ShapeType
@export var category: CategoryType
@export var icon: Texture2D # A imagem que vai para o carrinho e para a prateleira
