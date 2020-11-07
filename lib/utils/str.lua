
function utils.levenshteinDistance(str1, str2) 
    local str1, str2 = str1:lower(), str2:lower()
    local len1, len2 = #str1, #str2
    local char1, char2, distance = {}, {}, {}
    str1:gsub('.', function(c)
        table.insert(char1, c)
    end)
    str2:gsub('.', function(c)
        table.insert(char2, c)
    end)
    for i = 0, len1 do
        distance[i] = {}
    end
    for i = 0, len1 do
        distance[i][0] = i
    end
    for i = 0, len2 do
        distance[0][i] = i
    end
    for i = 1, len1 do
        for j = 1, len2 do
            distance[i][j] = math.min(distance[i - 1][j] + 1,
                distance[i][j - 1] + 1, distance[i - 1][j - 1] +
                    (char1[i] == char2[j] and 0 or 1))
        end
    end
    return distance[len1][len2] / #str2 -- note
end 
