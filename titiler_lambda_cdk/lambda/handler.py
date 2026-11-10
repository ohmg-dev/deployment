"""AWS Lambda handler."""

import asyncio
import logging

from mangum import Mangum
from rio_tiler.io import Reader
from titiler.application.main import app, titiler_templates
from titiler.application.settings import ApiSettings
from titiler.core.factory import (
    TilerFactory,
)
from titiler.extensions import (
    cogValidateExtension,
    cogViewerExtension,
    stacExtension,
    wmsExtension,
    wmtsExtension,
)

cog = TilerFactory(
    reader=Reader,
    router_prefix="/cog",
    add_ogc_maps=True,
    extensions=[
        cogValidateExtension(),
        cogViewerExtension(),
        stacExtension(),
        wmtsExtension(),
        wmsExtension(),
    ],
    enable_telemetry=False,
    templates=titiler_templates,
)

app.include_router(
    cog.router,
    prefix="/cog",
    tags=["Cloud Optimized GeoTIFF"],
)

try:
    asyncio.get_event_loop()
except RuntimeError:
    asyncio.set_event_loop(asyncio.new_event_loop())

logging.getLogger("mangum.lifespan").setLevel(logging.ERROR)
logging.getLogger("mangum.http").setLevel(logging.ERROR)

api_settings = ApiSettings()

handler = Mangum(app, api_gateway_base_path=api_settings.root_path, lifespan="auto")
