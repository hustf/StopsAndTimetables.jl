function lat_lon_to_lla(lat, lon)
    @assert endswith(lat, "°N") || endswith(lat, "°S")
    @assert endswith(lon, "°E") || endswith(lat, "°W")
    la = tryparse(Float64, lat[1 : end - 3])
    lo = tryparse(Float64, lon[1 : end - 3])
    if endswith(lat, "°W")
        lo = -lo
    end
    if endswith(lat, "°S")
        throw("Not ready for souther latitudes")
    else
        lat_lon_to_lla(la, lo)
    end
end
function lat_lon_to_lla(lat::Float64, lon::Float64)
    @assert lat >= 0
    LLA(lat, lon)
end

# Our main purpose is using for 
# https://nvdbapiles-v3.atlas.vegvesen.no/dokumentasjon/openapi/#/Vegnett/post_beta_vegnett_rute
# and testing shows coordinates must be in nationwide utm zone 33 
function lat_lon_to_utm(lat, lon; utm_zone = 33)
    ptlla = lat_lon_to_lla(lat, lon)
    lat_lon_to_utm(ptlla; utm_zone)
end
function lat_lon_to_utm(point_lla; utm_zone = 33)
    t = UTMfromLLA(utm_zone, true, Geodesy.wgs84)
    t(point_lla)
end

"""
    lat_lon_to_utm_tuple(lat, lon; utm_zone = 33)
    --> (easting::Int64, northing::Int64)

This is not useful for sub-meter resolution.
"""
function lat_lon_to_utm_tuple(lat, lon; utm_zone = 33)
    utm = lat_lon_to_utm(lat, lon; utm_zone)
    Int64(round(utm.x)), Int64(round(utm.y))
end