# discourse-docs-categories-tags

[ENGLISH](README.md) | **ESPAÑOL**

Mezcla todos los temas que llevan una etiqueta dada (por defecto: `wiki`) en la lista de temas
de una categoría concreta, de modo que aparecen como filas normales junto a los
temas que pertenecen nativamente a esa categoría.

Creado para el caso que el plugin Doc Categories no puede cubrir: ese plugin está limitado a una categoría,
así que no puede traer temas por etiqueta desde otras categorías.

## Instalación

Admin → Personalizar → Temas → Instalar → Desde un repositorio git, usando la URL de clonado
de este repositorio. Luego añade el componente a los temas que deban
usarlo.

## Ajustes

| Ajuste | Por defecto | Notas |
| --- | --- | --- |
| `tag_name` | `wiki` | Etiqueta cuyos temas se mezclan. Solo se usa la primera etiqueta. |
| `target_category` | — | La única categoría cuya lista recibe esos temas. Solo se usa la primera categoría. **Obligatorio**: no ocurre nada hasta que se configure. |

## Comportamiento

- Solo en la categoría destino, obtiene la lista de temas de la etiqueta para la pestaña actual
  y mezcla esos temas con la lista propia de la categoría. Las filas se renderizan
  con la lista de temas del núcleo, así que llevan los avatares, contadores de respuestas,
  actividad e insignias habituales.
- Los temas mezclados siguen el orden de la propia pestaña y no un orden aparte, así que
  Últimos sigue ordenado por actividad.
- Los temas que ya están en la categoría destino se omiten, así que nada aparece
  dos veces, y los temas fijados de la categoría siguen fijados arriba.
- Las insignias de categoría de origen se reactivan, ya que la lista ya no contiene
  una sola categoría. Las filas inyectadas también reciben la clase
  `docs-categories-tags-topic` para darles estilo.
- La etiqueta se oculta en la lista de esa categoría, donde solo repite lo que la
  página ya es. Sigue visible en las páginas de tema y en cualquier otro
  listado, y las demás etiquetas de esos temas no se tocan.
- La página propia de la etiqueta (`/tag/<tag>`) redirige a la categoría, ya que la
  categoría ahora contiene todo lo que lleva la etiqueta. Solo se redirigen las rutas de listado
  de esa etiqueta: la edición de etiquetas y las intersecciones `/tags/c/...` no se tocan.
- Un `#<tag>` escrito en el cuerpo de un post no renderiza nada, así que la etiqueta se aplica
  con el selector de etiquetas y no con hashtag. Los demás hashtags no se tocan y la palabra
  permanece en el markdown original.
- Las filas deshabilitadas se ocultan en la búsqueda de etiquetas del editor. Cuando una categoría
  restringe qué etiquetas permite, el núcleo lista las etiquetas no permitidas como
  filas deshabilitadas que explican por qué; esto oculta esa explicación. A diferencia de
  todo lo demás aquí, esa regla es global del sitio, no limitada a la categoría
  destino.
- Se ejecuta **solo** en la categoría destino. El outlet se dispara en cada página de descubrimiento,
  así que el componente comprueba el ID de la categoría actual y además omite las páginas de
  intersección etiqueta/categoría como `/tags/c/docs/other-tag`.
- Los resultados se guardan en caché en memoria por etiqueta y pestaña durante la sesión, así que cambiar
  de pestaña o navegar y volver no vuelve a pedirlos. Una recarga completa de la página
  los vuelve a pedir.
- Si la petición falla, la lista nativa se deja exactamente como estaba. No se muestra
  ningún error.

### Cómo se engancha

Los temas se mezclan mediante el plugin outlet `discovery-above`, que
recibe el modelo de la ruta. Así se evita sobrescribir las quince y pico clases de
ruta de categoría (`category`, `categoryNone`, `latestCategory`, `topCategory`
y compañía), a costa de mutar la lista de temas que entrega el outlet.

### La redirección de la etiqueta

La redirección es del lado del cliente, en el componente. Los Permalinks propios de Discourse
no pueden hacerlo: son una ruta comodín registrada al final, así que solo se activan
para URLs que no coinciden con nada más, y `/tag/<tag>` coincide primero con la ruta real de etiquetas.

Eso significa que los clics en etiquetas dentro de la app nunca muestran la página de la etiqueta, pero un acceso directo o
externo la carga brevemente antes de rebotar, y los rastreadores no la siguen.
Para un 301 real, redirige en el proxy inverso **y excluye el JSON**, que
este componente pide para sus propios datos:

```nginx
location = /tag/wiki { return 301 /c/docs/4; }
location ~ ^/tag/wiki/l/[a-z]+$ { return 301 /c/docs/4; }
# /tag/wiki/l/latest.json must NOT be redirected.
```

### Barra lateral de Doc Categories para temas listados en otra parte

Doc Categories decide su barra lateral según la categoría en la que vive un tema
(`doc-category-sidebar.js`, `activeCategory`), así que un tema al que enlaza un Docs Index
Topic pero que está archivado en otra categoría no recibe barra lateral, aunque forme parte
de la documentación. Este componente sobrescribe ese getter para que la pertenencia
siga al índice: la categoría cuyo índice enlaza al tema es la que gobierna la barra lateral. Los temas dentro de una categoría de documentación no se tocan.

Es independiente de la etiqueta a propósito: se basa en el índice, no en
`tag_name`, así que también cubre temas de documentación que no tienen nada que ver
con la mezcla anterior.

El parche se aplica a la **instancia** del servicio, no mediante
`api.modifyClass`. Doc Categories busca ese servicio en la primera línea de
su propio inicializador, así que cuando se ejecuta el código del tema ya está en la
caché del contenedor, y `modifyClass` se niega a tocar cualquier cosa inicializada
antes en el arranque: registra "Attempted to modify ... but it was already
initialized earlier in the boot process" y no hace nada.

Dos advertencias:

- Sombrea un getter del servicio de un plugin de terceros, que es
  API privada. Tres cosas protegen ese acoplamiento: `spec/system/doc_sidebar_spec.rb`
  se ejecuta contra el plugin real (la CI lo instala mediante
  `tests.requiredPlugins` en `about.json`), el componente registra una advertencia
  con su nombre si el plugin está instalado pero el getter ya no existe, y la CI
  también corre semanalmente para que los cambios upstream salgan a la luz sin un push. Si el getter
  desaparece, la barra lateral vuelve al comportamiento por defecto del plugin; nada más
  se rompe. Cuando el plugin no está, la búsqueda no encuentra nada y el
  componente queda inerte.
- La navegación anterior/siguiente es otro asunto y vive en
  `discourse-course-progress`, que resuelve la pertenencia de la misma manera. El
  ayudante que analiza los href está por eso duplicado en ambos repositorios; allí tiene
  pruebas unitarias.

### Lo que esto deliberadamente no hace

Dos problemas vecinos se resuelven mejor en Discourse mismo que aquí:

- **Etiquetas que deben ser invisibles fuera del uso de un bot** (términos de
  glosario aplicados automáticamente, por ejemplo). Ponlas en un grupo de etiquetas cuya única entrada
  de permisos sea el grupo de ese bot. `DiscourseTagging.hidden_tags` las oculta entonces
  en el servidor a todos salvo a ese grupo y a los administradores, en listas, temas,
  búsqueda y autocompletado. Ninguna hoja de estilos puede igualarlo.
- **Que se ofrezcan etiquetas que la categoría no permite.** La regla anterior
  solo oculta la explicación del núcleo. Lo que se ofrece lo decide el servidor.

### Límites conocidos

- La pestaña **Top** es aproximada. La lista de la etiqueta se pide con el
  filtro `top`, pero el orden mezclado es por número de vistas, que no es el mismo
  ranking que usa el servidor, y el periodo (`top/weekly`, etc.) no se transmite.
- Los temas mezclados aparecen un instante después de la lista nativa, cuando termina
  la petición, lo que reordena visiblemente la lista en conexiones lentas.
- Todo lo que lleva la etiqueta se pide de antemano, hasta 20 páginas, mientras que los temas
  propios de la categoría siguen paginando al hacer scroll.
- La regla del selector de etiquetas es el único comportamiento que queda sin probar.
- Las filas deshabilitadas ocultas en el selector de etiquetas no están cubiertas por una prueba:
  ejercitarlas requiere una categoría con grupos de etiquetas restringidos manejada mediante el
  editor. La regla del hashtag sí tiene prueba.

## Desarrollo

```bash
pnpm install
pnpm lint
```

La CI ejecuta el flujo compartido de temas de Discourse, que hace lint y ejecuta las pruebas del
tema. `spec/system/core_features_spec.rb` comprueba que las funciones del núcleo siguen
funcionando con el componente instalado; `spec/system/docs_categories_tags_spec.rb`
cubre la mezcla, el orden, la guarda de categoría y la desduplicación.

Las pruebas de sistema se ejecutan contra un Discourse real mediante la
[CLI discourse_theme](https://github.com/discourse/discourse_theme):

```bash
discourse_theme rspec .
```

Verificado con Discourse `2026.7.2` (estable) y `2026.9.0-latest`.

## Licencia

GPL-3.0. Consulta [LICENSE](LICENSE).

Texto de este README bajo [CC BY-NC-SA 4.0](CC-BY-NC-SA-4.0.txt).
