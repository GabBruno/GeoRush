extends Resource
class_name ProductData

# ==========================================
# --- ESTRUTURAS DE DADOS (ENUMS) ---
# Define as categorias restritas baseadas nas regras do seu Game Design Document (GDD).
# ==========================================

# As formas exatas do seu Documento de Design
enum ShapeType { ESFERA, CILINDRO, PARALELEPIPEDO, CUBO }
enum CategoryType { FRUTA, DOCE, BEBIDA, CONSERVA, MERCEARIA, LATICINIOS, FRIOS, MATINAIS }

# ==========================================
# --- PROPRIEDADES EXPORTADAS (INSPECTOR) ---
# Variáveis que aparecerão no editor da Godot para você criar e customizar
# cada produto individualmente (ex: criar o arquivo 'maca.tres').
# ==========================================

@export var product_name: String = "Novo Produto"
@export var shape: ShapeType
@export var category: CategoryType
@export var icon: Texture2D # A imagem que vai para o carrinho e para a prateleira
