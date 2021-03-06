/*
 * BSD 2-Clause License
 *
 * Copyright (c) 2021, Christoph Neuhauser
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * * Redistributions of source code must retain the above copyright notice, this
 *   list of conditions and the following disclaimer.
 *
 * * Redistributions in binary form must reproduce the above copyright notice,
 *   this list of conditions and the following disclaimer in the documentation
 *   and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <iostream>

#include <Utils/AppSettings.hpp>
#include <Utils/File/Logfile.hpp>
#include <Utils/File/FileUtils.hpp>
#include <Utils/Regex/TransformString.hpp>
#include <ImGui/ImGuiWrapper.hpp>
#include <ImGui/imgui_custom.h>
#include <ImGui/imgui_stdlib.h>
#include <boost/filesystem.hpp>

#include "Loaders/DataSetList.hpp"
#include "StressLineTracingRequester.hpp"

StressLineTracingRequester::StressLineTracingRequester(void* context) : context(context), worker(context) {
    loadMeshList();
}

void StressLineTracingRequester::loadMeshList() {
    meshNames.clear();
    meshFilenames.clear();
    meshNames.push_back("Local file...");

    const std::string lineDataSetsDirectory = sgl::AppSettings::get()->getDataDirectory() + "LineDataSets/";
    std::string filename = lineDataSetsDirectory + "meshes.json";
    if (sgl::FileUtils::get()->exists(filename)) {
        // Parse the passed JSON file.
        std::ifstream jsonFileStream(filename.c_str());
        Json::CharReaderBuilder builder;
        JSONCPP_STRING errorString;
        Json::Value root;
        if (!parseFromStream(builder, jsonFileStream, &root, &errorString)) {
            sgl::Logfile::get()->writeError(errorString);
            return;
        }
        jsonFileStream.close();

        Json::Value sources = root["meshes"];
        for (Json::Value::const_iterator sourceIt = sources.begin(); sourceIt != sources.end(); ++sourceIt) {
            DataSetInformation dataSetInformation;
            Json::Value source = *sourceIt;

            meshNames.push_back(source["name"].asString());
            meshFilenames.push_back(source["filename"].asString());
        }
    }
}

void StressLineTracingRequester::renderGui() {
    sgl::ImGuiWrapper::get()->setNextWindowStandardPosSize(3072, 1146, 760, 628);
    if (ImGui::Begin("Stress Line Tracing", &showWindow)) {
        bool changed = false;
        if (ImGui::Combo("Data Set", &selectedMeshIndex, meshNames.data(), meshNames.size())) {
            if (selectedMeshIndex >= 1) {
                meshFilename = meshFilenames.at(selectedMeshIndex - 1);
                changed = true;
            }
        }
        if (selectedMeshIndex == 0) {
            ImGui::InputText("##meshfilenamelabel", &meshFilename);
            ImGui::SameLine();
            if (ImGui::Button("Load File")) {
                changed = true;
            }
        }

        changed |= ImGui::Checkbox("##customlinedensity", &useCustomLineDensity);ImGui::SameLine();
        changed |= ImGui::SliderFloatActive("Line Density", &lineDensCtrl, 1, 50, useCustomLineDensity);
        changed |= ImGui::Checkbox("##customseeddensity", &useCustomSeedDensity);ImGui::SameLine();
        changed |= ImGui::SliderFloatActive("Seed Density", &seedDensCtrl, 1, 30, useCustomSeedDensity);
        changed |= ImGui::Checkbox("##customnumlevels", &useCustomNumLevels);ImGui::SameLine();
        changed |= ImGui::SliderIntActive("#Levels", &numLevels, 1, 5, useCustomNumLevels);
        changed |= ImGui::Checkbox("Major##tracepsmajor", &traceMajorPS); ImGui::SameLine();
        changed |= ImGui::Checkbox("Medium##tracepsmedium", &traceMediumPS); ImGui::SameLine();
        changed |= ImGui::Checkbox("Minor##tracepsminor", &traceMinorPS);

        if (ImGui::CollapsingHeader(
                "Advanced Settings", nullptr, ImGuiTreeNodeFlags_DefaultOpen)) {
            changed |= ImGui::Combo(
                    "Seed Strategy", (int*)&seedStrategy, SEED_STRATEGY_NAMES,
                    IM_ARRAYSIZE(SEED_STRATEGY_NAMES));
            changed |= ImGui::Combo(
                    "Tracing Algorithm", (int*)&tracingAlgorithm, TRACING_ALGORITHM_NAMES,
                    IM_ARRAYSIZE(TRACING_ALGORITHM_NAMES));
            changed |= ImGui::SliderInt("Max Angle Deviation", &maxAngleDeviation, 1, 20);
            changed |= ImGui::Checkbox("Merge Close PSLs", &mergingOpt);
            changed |= ImGui::Checkbox("Snap Close PSLs", &snappingOpt);
            changed |= ImGui::SliderFloat3("Merging Thresholds", &multiMergingThresholds.x, 1, 5);
        }

        if (changed) {
            requestNewData();
        }
    }
    ImGui::End();
}

void StressLineTracingRequester::requestNewData() {
    if (meshFilename.empty()) {
        return;
    }

    Json::Value request;
    const std::string lineDataSetsDirectory = sgl::AppSettings::get()->getDataDirectory() + "LineDataSets/";
    request["fileName"] = boost::filesystem::absolute(lineDataSetsDirectory + meshFilename).c_str();
    if (lineDensCtrl > 0 && useCustomLineDensity) {
        request["lineDensCtrl"] = lineDensCtrl;
    } else {
        request["lineDensCtrl"] = "default";
    }
    if (numLevels > 0 && useCustomNumLevels) {
        request["numLevels"] = numLevels;
    } else {
        request["numLevels"] = "default";
    }
    request["seedStrategy"] = SEED_STRATEGY_ABBREVIATIONS[int(seedStrategy)];
    if (seedDensCtrl > 0 && useCustomSeedDensity) {
        request["seedDensCtrl"] = seedDensCtrl;
    } else {
        request["seedDensCtrl"] = "default";
    }
    if (traceMajorPS) {
        request["selectedPrincipalStressField"].append(1);
    }
    if (traceMediumPS) {
        request["selectedPrincipalStressField"].append(2);
    }
    if (traceMinorPS) {
        request["selectedPrincipalStressField"].append(3);
    }
    request["mergingOpt"] = mergingOpt;
    request["snappingOpt"] = snappingOpt;
    request["maxAngleDevi"] = maxAngleDeviation;
    for (int i = 0; i < 3; i++) {
        request["multiMergingThresholds"].append(multiMergingThresholds[i]);
    }
    request["traceAlgorithm"] = TRACING_ALGORITHM_ABBREVIATIONS[int(tracingAlgorithm)];
    std::cout << request << std::endl;
    worker.queueRequestJson(request);
}

bool StressLineTracingRequester::getHasNewData(DataSetInformation& dataSetInformation) {
    Json::Value reply;
    if (worker.getReplyJson(reply)) {
        dataSetInformation = DataSetInformation();
        dataSetInformation.type = DATA_SET_TYPE_STRESS_LINES;
        dataSetInformation.hasCustomTransform = true;
        dataSetInformation.transformMatrix = parseTransformString("rotate(270°, 1, 0, 0)");
        dataSetInformation.version = 3;
        dataSetInformation.meshFilename = meshFilename;

        std::string meshName;
        if (selectedMeshIndex == 0) {
            meshName = sgl::FileUtils::get()->getPureFilename(meshFilename);
        } else {
            meshName = meshNames.at(selectedMeshIndex);
        }
        dataSetInformation.name = meshName;

        Json::Value filenames = reply["fileName"];
        if (filenames.isArray()) {
            for (Json::Value::const_iterator filenameIt = filenames.begin();
                 filenameIt != filenames.end(); ++filenameIt) {
                dataSetInformation.filenames.push_back(filenameIt->asString());
            }
        } else {
            dataSetInformation.filenames.push_back(filenames.asString());
        }

        // Optional data: Attribute (importance criteria) display names.
        if (reply.isMember("attributes")) {
            Json::Value attributes = reply["attributes"];
            if (attributes.isArray()) {
                for (Json::Value::const_iterator attributesIt = attributes.begin();
                     attributesIt != attributes.end(); ++attributesIt) {
                    dataSetInformation.attributeNames.push_back(attributesIt->asString());
                }
            } else {
                dataSetInformation.attributeNames.push_back(attributes.asString());
            }
        } else {
            //dataSetInformation.attributeNames.push_back("Sigma");
            //dataSetInformation.attributeNames.push_back("Sigma_vM");
            //dataSetInformation.attributeNames.push_back("Sigma_xx");
            //dataSetInformation.attributeNames.push_back("Sigma_yy");
            //dataSetInformation.attributeNames.push_back("Sigma_zz");
            //dataSetInformation.attributeNames.push_back("Sigma_yz");
            //dataSetInformation.attributeNames.push_back("Sigma_zx");
            //dataSetInformation.attributeNames.push_back("Sigma_xy");

            dataSetInformation.attributeNames.push_back("Principal Stress");
            dataSetInformation.attributeNames.push_back("von Mises Stress");
            dataSetInformation.attributeNames.push_back("Normal Stress (xx)");
            dataSetInformation.attributeNames.push_back("Normal Stress (yy)");
            dataSetInformation.attributeNames.push_back("Normal Stress (zz)");
            dataSetInformation.attributeNames.push_back("Shear Stress (yz)");
            dataSetInformation.attributeNames.push_back("Shear Stress (zx)");
            dataSetInformation.attributeNames.push_back("Shear Stress (xy)");
        }

        // Optional stress line data: Degenerate points file.
        if (reply.isMember("degeneratePoints")) {
            const std::string lineDataSetsDirectory = sgl::AppSettings::get()->getDataDirectory() + "LineDataSets/";
            dataSetInformation.degeneratePointsFilename =
                    lineDataSetsDirectory + reply["degenerate_points"].asString();
        }

        return true;
    }
    return false;
}
