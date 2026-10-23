# RefugeZ Motorcycle Pack

Motocicletas para Project Zomboid Build 42 (42.19+). Mod autocontido, sem dependências.

## Motos

| Moto | ID do veículo | Perfil de animação |
|---|---|---|
| Old West Bike | `Base.RZMoto_OldWest` | `OW` |
| Ghost Rider | `Base.RZMoto_GhostRider` | `GR` |
| AKT TT 200 DS (normal, Premium Matte e Matte) | `Base.RZMoto_AKTTT200`, `_Premium`, `_Matte` | `AK` |
| Post-Apo | `Base.RZMoto_PostApo` | `PA` |
| Street Three (normal e Matte) | `Base.RZMoto_StreetThree`, `_Matte` | `ST` |
| Honda CRF 450 | `Base.RZMoto_HondaCRF450` | `CF` |
| CWS M111 com sidecar | `Base.RZMoto_CWSM111` | `CW` (piloto), `CS` (passageiro) |
| CWS M111 Halloween | `Base.RZMoto_CWSM111_Halloween` | `CW` (piloto), `CS` (passageiro) |
| Honda Motra | `Base.RZMoto_HondaMotra` | `MT` |
| Honda Shadow RS 2010 | `Base.RZMoto_HondaShadowRS` | `HS` |
| Harley-Davidson Electra Glide Police | `Base.RZMoto_HarleyPolice` | `HP` |
| Harley-Davidson | `Base.RZMoto_HarleyDavidson` | `HD` |
| Harley Custom v1.2 | `Base.RZMoto_HarleyCustom` | `HC` |
| Delivery Electric Scooter | `Base.RZMoto_DeliveryScooter` | `DS` |

## Recursos

- Revista **Manual de Manutenção RefugeZ** (`Base.RZ_MotoMag`): ensina as 102 receitas
  de peças. As receitas nascem trancadas (`needToBeLearn = true`) e também se aprendem
  sozinhas três níveis acima da habilidade exigida (`AutoLearnAll`), como as revistas de
  receita da B42. Nasce em garagens, oficinas, autopeças, livrarias e no baú traseiro
  das motos.

- Fabricação de todas as 102 peças exclusivas das motos na categoria Tuning: tanques,
  bancos, para-lamas, três classes de pneus, baús, bagageiros, coldre e bateria da scooter.
  Variantes compartilham as receitas das motos-base. Traduções EN/PTBR.
  Detalhes em [design/crafting/README.md](design/crafting/README.md).

- Tuk-tuk (`Base.RZMoto_TukTuk`): veículo tratado como carro, com motorista central,
  dois passageiros, porta-bagagens de 25, manutenção e animações de ocupantes vanilla.
  Modelo original convertido com acabamento fosco 4K, três rodas visíveis e tela de
  mecânica própria. Não usa queda, levantar moto ou carga no trailer de motos.
  Validado com parser/FBX e física nativos; requer teste em partida e servidor dedicado.
  Detalhes em [design/tuk-tuk/README.md](design/tuk-tuk/README.md).

- Trailer de motos (`Base.RZMoto_Trailer`): dois trilhos para carregar motos próximas pelo
  menu de contexto. Reboque nativo, rodas independentes e textura 4K no padrão das motos.
  Pare os veículos, saia do rebocador e retire a chave da ignição da moto; tenha a chave
  no inventário ou ligação direta. Para descarregar, deixe espaço atrás do trailer.
  Motos com sidecar não cabem. A carga usa os itens originais das peças e bagagens.
  Detalhes em [design/moto-trailer/README.md](design/moto-trailer/README.md).
  Ainda requer teste em partida e servidor dedicado.

- CWS M111 preta com dois lugares: piloto e passageiro sentado no sidecar, com entrada pelo lado externo direito. Estepe removível compatível com as rodas; manutenção independente da roda do sidecar.

- Piloto com animações próprias por moto: andando, parado (pé esquerdo no chão quando alcança),
  ré, guidão virando junto com a direção, subir e descer pela lateral.
- Rodas, discos e conjunto dianteiro animados; peças e baús removíveis; tela de mecânica própria.
- Harley: sirene e giroflex azul/vermelho (menu radial, tecla **V**), com a bateria e a
  sincronização nativas das viaturas.
- Scooter elétrico com bateria recarregável e containers de 15 na frente / 25 atrás.
- Old West Bike com coldre lateral removível, capacidade 5 e ícone próprio de couro.
- Honda Motra a gasolina, tanque de 5 L, bagageiros removíveis com loot: 15 na frente / 25 atrás.
- Queda: perda brusca de velocidade (batida) derruba o piloto.
- Moto caída: opção "Levantar a moto" no menu de contexto/radial. Ao descer de uma moto parada e
  levemente inclinada, ela volta a ficar em pé.

## Como as animações são feitas

As animações do piloto são geradas por uma ferramenta própria (fora do pacote do mod) a partir das
animações vanilla `Bob_IdleDriving` e `Bob_Idle`. O banco, as manoplas, as pedaleiras e o eixo de
direção são medidos nos modelos das próprias motos e mãos/pés são posicionados por IK. Cada perfil
fica em `42/media/anims_X/Bob/RZMoto_<perfil>.x`. Os AnimSets em
`42/media/AnimSets/player-vehicle/*/rzmoto_*.xml` são gerados a partir dos XML vanilla.

Harley-Davidson civil: somente a motocicleta do GLB fornecido, sem a base de exposição ou o
corrimão. Inclui textura 4K, rodas/direção animadas, peças removíveis e perfil próprio do piloto.
Os arquivos e animações passaram pelos carregadores nativos B42; condução e servidor dedicado
ainda precisam de validação em execução.

Variáveis de animação (definidas em `RZMoto_Anim.lua`): `RZMotoRider`, `RZMotoProfile`,
`RZMotoMotion` (`ride`/`stop`/`back`), `RZSteerX`/`RZSteerY`.

## Configuração por moto

Cada script de veículo tem a peça oculta `RZMotoConfig`:

| Campo | Uso |
|---|---|
| `profile` | perfil de animação (`AK`, `PA`, `ST`, `CF`, `CW`, `MT`, `HS`, `HP`, `HD`, `HC`, `DS`) |
| `passengerProfile` | perfil opcional para assentos além do piloto (`CS` no sidecar da CWS) |
| `crashSpeedDrop` | queda de velocidade (km/h em 0,3 s) que derruba o piloto; 0 desliga |
| `motionDeadzone` | km/h abaixo do qual a moto conta como parada |
| `hideHeldItems` | esconde os itens das mãos montado |
| `mountWithInteract` | tecla Interagir sobe direto na moto |
| `riderDepth` | corrige a ordem de desenho do piloto em bancos altos |
| `bagChance` | chance (0–100) de nascer com os baús |

## Rede e segurança

O comando `rightVehicle` (levantar moto caída) é revalidado no servidor. O sistema do trailer
acrescenta os pedidos `RZMotoTrailer.load` e `unload`: o servidor verifica proximidade,
chaves, ocupantes, velocidade, capacidade e espaço de saída antes de guardar ou restaurar
a moto. Itens reais ficam nos cofres nativos do trailer; o resumo visual usa sincronização
nativa de peças. As animações continuam calculadas em cada cliente com o estado do veículo.

## Créditos

Modelos e licenças: [CREDITS.md](CREDITS.md).
